class_name PerfCore
extends RefCounted
## The rows of the budget that need no window and no run: hand classification, legal move
## generation, and the bots' decisions. Every sample is seeded through RandomStream.

const FULL_HAND: int = 20
const MAX_RANDOM_CARDS: int = 20
## Games played to collect real plays for the classifier.
const PLAY_GAMES: int = 40
const BOT_TIERS: Array[String] = ["easy", "medium", "hard"]
const USEC_PER_MSEC: float = 1000.0

var _seed: int
var _rules: RuleSet = RuleSet.default_rules()
var _map: PackedByteArray = Ranks.identity_map()


func _init(first_seed: int) -> void:
	_seed = first_seed


## Time per Classifier.classify call, over real plays taken from seeded games and over
## random hands of 1 to 20 cards, half and half.
func classification(hands: int) -> PerfRow:
	var stream: RandomStream = RandomStream.new(RandomStreams.derive_seed(_seed, "perf_classify"))
	var plays: Array[PackedByteArray] = _real_plays()
	var usec: PackedFloat64Array = PackedFloat64Array()
	for index: int in hands:
		var counts: PackedByteArray
		if index % 2 == 0 and not plays.is_empty():
			counts = plays[stream.next_int(0, plays.size() - 1)]
		else:
			counts = _random_counts(stream, stream.next_int(1, MAX_RANDOM_CARDS))
		var started: int = Time.get_ticks_usec()
		Classifier.classify(counts, _rules, _map)
		usec.append(Time.get_ticks_usec() - started)
	var sorted: PackedFloat64Array = PerfRow.sorted_of(usec)
	var p99: float = PerfRow.percentile(sorted, 0.99)
	var measured: String = (
		"median %.1f us, p99 %.1f us, worst %.1f us"
		% [PerfRow.percentile(sorted, 0.5), p99, sorted[-1]]
	)
	return PerfRow.judged(
		"Hand classification",
		"under %.0f us per call (O(15))" % PerfLimits.CLASSIFY_MAX_USEC,
		measured,
		p99 < PerfLimits.CLASSIFY_MAX_USEC,
		"%d calls, %d real plays in the pool" % [hands, plays.size()],
		"judged on p99"
	)


## Time to generate every legal move for a random 20-card hand, leading and following.
func move_generation(hands: int) -> PerfRow:
	var stream: RandomStream = RandomStream.new(RandomStreams.derive_seed(_seed, "perf_movegen"))
	var usec: PackedFloat64Array = PackedFloat64Array()
	for index: int in hands:
		var counts: PackedByteArray = _random_counts(stream, FULL_HAND)
		var mask: int = _mask_of(counts)
		var current: Pattern = null
		if index % 2 == 1:
			current = _random_lead(stream)
		var started: int = Time.get_ticks_usec()
		MoveGenerator.generate(counts, mask, current, _rules, _map)
		usec.append(Time.get_ticks_usec() - started)
	var sorted: PackedFloat64Array = PerfRow.sorted_of(usec)
	var median: float = PerfRow.percentile(sorted, 0.5)
	return PerfRow.judged(
		"Legal moves, 20-card hand",
		"median under %.0f us" % PerfLimits.MOVEGEN_MEDIAN_MAX_USEC,
		"median %.0f us, p99 %.0f us" % [median, PerfRow.percentile(sorted, 0.99)],
		median < PerfLimits.MOVEGEN_MEDIAN_MAX_USEC,
		"%d hands, half leading and half following" % hands
	)


## One row per tier from Easy to Hard: each plays seeded deals with all three seats the
## tier, through SelfPlay with a clock, so every decision is timed.
func bots(deals: int) -> Array[PerfRow]:
	var rows: Array[PerfRow] = []
	for tier_name: String in BOT_TIERS:
		rows.append(_bot_row(tier_name, deals))
	return rows


## Expert through ExpertRunner at its real deadline, over a short sample.
func expert(deals: int) -> PerfRow:
	var play: ExpertPlay = ExpertPlay.new()
	var limit: int = BotConfig.DEFAULT_WEIGHTS.expert_deadline_usec
	for index: int in deals:
		play.expert_wins(SelfPlay.deal_from_seed(_seed + index), limit)
	if play.times.is_empty():
		return PerfRow.unmeasured("Bot decision, Expert", _expert_budget(), "no deals asked for")
	var p99_ms: float = play.p99_usec() / USEC_PER_MSEC
	var note: String = "at the %d ms deadline on %d worker threads" % [limit / 1000, _threads()]
	if play.illegal > 0:
		note += ", %d illegal actions" % play.illegal
	return PerfRow.judged(
		"Bot decision, Expert",
		_expert_budget(),
		"p99 %.1f ms" % p99_ms,
		p99_ms < PerfLimits.EXPERT_P99_MAX_MS and play.illegal == 0,
		(
			"%d decisions over %d deals (%d games); %s"
			% [play.times.size(), deals, deals * 2, play.samples_line()]
		),
		note
	)


func _expert_budget() -> String:
	return "p99 under %.0f ms, worker thread with deadline" % PerfLimits.EXPERT_P99_MAX_MS


func _threads() -> int:
	return maxi(1, OS.get_processor_count() - 1)


func _bot_row(tier_name: String, deals: int) -> PerfRow:
	var tier: BotConfig.Tier = TournamentRun.CONFIGS[tier_name]
	var table: SeatRules = SeatRules.uniform(_rules, _map)
	var usec: PackedFloat64Array = PackedFloat64Array()
	var illegal: int = 0
	for index: int in deals:
		var config: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, tier, _seed + index)
		var seats: Array[BotConfig] = [config, config, config]
		var result: SelfPlayResult = SelfPlay.play_round(
			SelfPlay.deal_from_seed(_seed + index), 0, seats, table, Time.get_ticks_usec
		)
		illegal += result.illegal_actions
		for taken: int in result.decision_usec:
			usec.append(taken)
	var sorted: PackedFloat64Array = PerfRow.sorted_of(usec)
	var median_ms: float = PerfRow.percentile(sorted, 0.5) / USEC_PER_MSEC
	var p99_ms: float = PerfRow.percentile(sorted, 0.99) / USEC_PER_MSEC
	var ok: bool = (
		not sorted.is_empty()
		and median_ms < PerfLimits.BOT_MEDIAN_MAX_MS
		and p99_ms < PerfLimits.BOT_P99_MAX_MS
		and illegal == 0
	)
	return PerfRow.judged(
		"Bot decision, %s" % tier_name.capitalize(),
		(
			"median under %.0f ms, p99 under %.0f ms"
			% [PerfLimits.BOT_MEDIAN_MAX_MS, PerfLimits.BOT_P99_MAX_MS]
		),
		(
			"median %.2f ms, p99 %.2f ms, worst %.2f ms"
			% [median_ms, p99_ms, (sorted[-1] if not sorted.is_empty() else 0.0) / USEC_PER_MSEC]
		),
		ok,
		"%d decisions over %d deals" % [sorted.size(), deals],
		"" if illegal == 0 else "%d illegal actions" % illegal
	)


## The rank counts of every non-pass play in a few seeded Medium games.
func _real_plays() -> Array[PackedByteArray]:
	var plays: Array[PackedByteArray] = []
	var config: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.MEDIUM, _seed)
	var seats: Array[BotConfig] = [config, config, config]
	var table: SeatRules = SeatRules.uniform(_rules, _map)
	for index: int in PLAY_GAMES:
		var result: SelfPlayResult = SelfPlay.play_round(
			SelfPlay.deal_from_seed(_seed + index), 0, seats, table
		)
		for play: PublicPlay in result.history:
			if not play.pattern.type == Pattern.Type.PASS:
				plays.append(play.counts)
	return plays


func _random_lead(stream: RandomStream) -> Pattern:
	var counts: PackedByteArray = _random_counts(stream, FULL_HAND)
	var moves: Array[Pattern] = MoveGenerator.generate(counts, _mask_of(counts), null, _rules, _map)
	return moves[stream.next_int(0, moves.size() - 1)]


func _random_counts(stream: RandomStream, cards: int) -> PackedByteArray:
	var deck: PackedInt32Array = Deck.generate()
	var result: PackedByteArray = PackedByteArray()
	result.resize(Ranks.COUNT)
	for index: int in cards:
		var pick: int = stream.next_int(index, deck.size() - 1)
		var card: int = deck[pick]
		deck[pick] = deck[index]
		deck[index] = card
		result[Deck.rank_of(card)] += 1
	return result


func _mask_of(counts: PackedByteArray) -> int:
	var mask: int = 0
	for rank: int in Ranks.COUNT:
		mask |= (1 << rank) if counts[rank] > 0 else 0
	return mask
