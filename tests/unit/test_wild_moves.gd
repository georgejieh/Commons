extends GdUnitTestSuite
## Wild ranks (ADR 0029) in the rules engine: every generated move is a legal reading of
## the cards it spends, every legal reading of every set of cards is generated, readings
## of one set come strongest first, and with no wild card nothing changes.

const SEED: int = 2918
const FULL_HAND: int = 20
const LEGAL_HANDS: int = 60
const FOLLOWS: int = 3
const SUBSET_HANDS: int = 40
const MIN_SUBSET_CARDS: int = 3
const MAX_SUBSET_CARDS: int = 8
const MAX_SUBSET_WILDS: int = 3
const PLAIN_HANDS: int = 300
const MAX_STEPS: int = 10000
const TIMED_HANDS: int = 60
const LEAN_BUDGET_USEC: int = 10000
const FULL_BUDGET_USEC: int = 25000

var _map: PackedByteArray = Ranks.identity_map()


func _configs() -> Array[RuleSet]:
	var one: Array[int] = [Ranks.SEVEN]
	var two: Array[int] = [Ranks.SEVEN, Ranks.QUEEN]
	return [
		WildReference.rules(one, false),
		WildReference.rules(one, true),
		WildReference.rules(two, false),
		WildReference.rules(two, true),
	]


## A random hand of cards, holding wilds wild cards first, as many as the deck has. Every
## loop has a step limit, so a bad request ends the test instead of hanging it.
func _hand(stream: RandomStream, cards: int, wilds: int, rules: RuleSet) -> PackedByteArray:
	var counts: PackedByteArray = PackedByteArray()
	counts.resize(Ranks.COUNT)
	var wild: Array[int] = rules.wild_ranks()
	var wanted: int = mini(wilds, 4 * wild.size())
	var placed: int = 0
	var steps: int = 0
	while placed < wanted and steps < MAX_STEPS:
		steps += 1
		var rank: int = wild[stream.next_int(0, wild.size() - 1)]
		if counts[rank] < 4:
			counts[rank] += 1
			placed += 1
	while placed < cards and steps < MAX_STEPS:
		steps += 1
		var rank: int = stream.next_int(0, Ranks.COUNT - 1)
		var limit: int = 1 if rank >= Ranks.SMALL_JOKER else 4
		if counts[rank] < limit and not rules.is_wild(rank):
			counts[rank] += 1
			placed += 1
	if steps >= MAX_STEPS:
		fail("could not deal the hand asked for")
	return counts


func _generate(counts: PackedByteArray, current: Pattern, rules: RuleSet) -> Array[Pattern]:
	return MoveGenerator.generate(counts, MoveReference.mask_of(counts), current, rules, _map)


## A random play from a random wild hand, to answer.
func _random_play(stream: RandomStream, rules: RuleSet) -> Pattern:
	var moves: Array[Pattern] = _generate(
		_hand(stream, FULL_HAND, stream.next_int(0, 4), rules), null, rules
	)
	return moves[stream.next_int(0, moves.size() - 1)]


func _legal_failures(
	counts: PackedByteArray, current: Pattern, rules: RuleSet
) -> PackedStringArray:
	var failures: PackedStringArray = []
	for move: Pattern in _generate(counts, current, rules):
		var spent: PackedByteArray = move.spent_counts()
		for rank: int in Ranks.COUNT:
			if spent[rank] > counts[rank]:
				failures.append("spends cards it lacks: " + RankText.describe(move))
		if Readings.checked(move, spent, rules, _map) == null:
			failures.append("not a reading of its cards: " + RankText.describe(move))
		if current != null and not PlayComparator.beats(move, current, rules):
			failures.append("does not beat the table: " + RankText.describe(move))
		var reading: PackedByteArray = move.counts()
		for joker: int in [Ranks.SMALL_JOKER, Ranks.BIG_JOKER]:
			if reading[joker] != spent[joker]:
				failures.append("a joker stand-in: " + RankText.describe(move))
	return failures


func test_every_generated_move_is_a_legal_reading_of_its_cards() -> void:
	var stream: RandomStream = RandomStream.new(SEED)
	var failures: PackedStringArray = []
	for rules: RuleSet in _configs():
		for _hand_index: int in LEGAL_HANDS:
			var wilds: int = stream.next_int(1, 4 * rules.wild_ranks().size())
			var counts: PackedByteArray = _hand(stream, FULL_HAND, wilds, rules)
			failures.append_array(_legal_failures(counts, null, rules))
			for _follow: int in FOLLOWS:
				failures.append_array(_legal_failures(counts, _random_play(stream, rules), rules))
	assert_array(Array(failures.slice(0, 5))).is_empty()


## Small hands, so the brute force can read every subset.
func _subset_failures(
	counts: PackedByteArray, current: Pattern, rules: RuleSet
) -> PackedStringArray:
	var failures: PackedStringArray = []
	var moves: Array[Pattern] = _generate(counts, current, rules)
	for subset: PackedByteArray in WildReference.subsets(counts):
		var brute: Dictionary[int, Pattern] = WildReference.readings(subset, rules, _map)
		var plain: bool = WildReference.wild_cards(subset, rules) == 0
		for reading: Pattern in brute.values():
			if current != null and not PlayComparator.beats(reading, current, rules):
				continue
			if not WildReference.covered(reading, moves, rules):
				failures.append("missing " + RankText.describe(reading))
			if plain and not moves.any(func(move: Pattern) -> bool: return move.equals(reading)):
				failures.append("missing natural " + RankText.describe(reading))
		var listed: Array[Pattern] = Readings.of(subset, rules, _map)
		for reading: Pattern in listed:
			if not brute.has(reading.identity()):
				failures.append("Readings invents " + RankText.describe(reading))
		for reading: Pattern in brute.values():
			if not WildReference.covered(reading, listed, rules):
				failures.append("Readings misses " + RankText.describe(reading))
	return failures


func test_every_reading_of_every_subset_is_generated() -> void:
	var stream: RandomStream = RandomStream.new(SEED + 1)
	var failures: PackedStringArray = []
	for rules: RuleSet in _configs():
		for index: int in SUBSET_HANDS:
			var cards: int = stream.next_int(MIN_SUBSET_CARDS, MAX_SUBSET_CARDS)
			var wilds: int = stream.next_int(1, MAX_SUBSET_WILDS)
			var counts: PackedByteArray = _hand(stream, cards, wilds, rules)
			var current: Pattern = null if index % 2 == 0 else _random_play(stream, rules)
			failures.append_array(_subset_failures(counts, current, rules))
	assert_array(Array(failures.slice(0, 5))).is_empty()


func test_a_hand_with_no_wild_card_gets_exactly_the_plain_moves() -> void:
	var stream: RandomStream = RandomStream.new(SEED + 2)
	var plain: RuleSet = RuleSet.default_rules()
	var mismatches: int = 0
	for index: int in PLAIN_HANDS:
		var rules: RuleSet = _configs()[index % 4]
		if rules.five_plus_is_bomb():
			continue
		var counts: PackedByteArray = _hand(stream, stream.next_int(1, FULL_HAND), 0, rules)
		var current: Pattern = null
		if index % 3 == 0:
			current = _generate(counts, null, plain)[0]
		var wild: Array[Pattern] = _generate(counts, current, rules)
		var expected: Array[Pattern] = _generate(counts, current, plain)
		if wild.size() != expected.size():
			mismatches += 1
			continue
		for at: int in wild.size():
			if not wild[at].equals(expected[at]) or not wild[at].spent.is_empty():
				mismatches += 1
				break
	assert_int(mismatches).is_equal(0)


## Plays of every kind from wild hands, for the order properties.
func _sample(stream: RandomStream, rules: RuleSet, count: int) -> Array[Pattern]:
	var sample: Array[Pattern] = []
	for _try: int in count:
		if sample.size() >= count:
			break
		var moves: Array[Pattern] = _generate(
			_hand(stream, FULL_HAND, stream.next_int(0, 5), rules), null, rules
		)
		var bombs: Array[Pattern] = moves.filter(
			func(move: Pattern) -> bool: return FollowPolicy.is_bomb(move)
		)
		sample.append(moves[stream.next_int(0, moves.size() - 1)])
		if not bombs.is_empty():
			sample.append(bombs[stream.next_int(0, bombs.size() - 1)])
	return sample


func test_comparison_is_a_strict_order() -> void:
	var stream: RandomStream = RandomStream.new(SEED + 3)
	var broken: int = 0
	for rules: RuleSet in _configs():
		var sample: Array[Pattern] = _sample(stream, rules, 36)
		var none: PackedByteArray = PackedByteArray()
		sample.append(
			Pattern.new(Pattern.Type.ROCKET, Ranks.SMALL_JOKER, 1, 2, none, Ranks.SMALL_JOKER)
		)
		for a: Pattern in sample:
			if PlayComparator.beats(a, a, rules):
				broken += 1
			for b: Pattern in sample:
				broken += _order_breaks(a, b, sample, rules)
	assert_int(broken).is_equal(0)


## Asymmetric, total where the shapes can meet, and transitive through every c.
func _order_breaks(a: Pattern, b: Pattern, sample: Array[Pattern], rules: RuleSet) -> int:
	var breaks: int = 0
	var ab: bool = PlayComparator.beats(a, b, rules)
	var ba: bool = PlayComparator.beats(b, a, rules)
	if ab and ba:
		breaks += 1
	var meet: bool = a.shape() == b.shape() or FollowPolicy.is_bomb(a) or FollowPolicy.is_bomb(b)
	var same: String = WildReference.shape_of(a, rules)
	var tied: bool = a.key == b.key and same == WildReference.shape_of(b, rules)
	if meet and not tied and not ab and not ba:
		breaks += 1
	if ab:
		for c: Pattern in sample:
			if PlayComparator.beats(b, c, rules) and not PlayComparator.beats(a, c, rules):
				breaks += 1
	return breaks


func test_readings_come_strongest_first() -> void:
	var stream: RandomStream = RandomStream.new(SEED + 4)
	var unordered: int = 0
	for rules: RuleSet in _configs():
		for _index: int in 40:
			var cards: int = stream.next_int(2, 8)
			var counts: PackedByteArray = _hand(stream, cards, stream.next_int(1, 3), rules)
			var listed: Array[Pattern] = Readings.of(counts, rules, _map)
			for at: int in range(1, listed.size()):
				if Readings.stronger(listed[at], listed[at - 1], rules):
					unordered += 1
				if listed[at].equals(listed[at - 1]):
					unordered += 1
	assert_int(unordered).is_equal(0)


func test_lean_generation_is_the_complete_list_less_what_bots_never_need() -> void:
	var stream: RandomStream = RandomStream.new(SEED + 5)
	var mismatches: int = 0
	for rules: RuleSet in _configs():
		for index: int in 30:
			var counts: PackedByteArray = _hand(stream, FULL_HAND, stream.next_int(1, 4), rules)
			var current: Pattern = null if index % 2 == 0 else _random_play(stream, rules)
			var mask: int = MoveReference.mask_of(counts)
			var lean: Array[Pattern] = MoveGenerator.generate(
				counts, mask, current, rules, _map, true
			)
			var kept: Array[Pattern] = _generate(counts, current, rules).filter(
				func(move: Pattern) -> bool: return WildSupply.is_lean(move)
			)
			if lean.size() != kept.size():
				mismatches += 1
				continue
			for at: int in lean.size():
				if not lean[at].equals(kept[at]):
					mismatches += 1
					break
	assert_int(mismatches).is_equal(0)


## Budgets (ADR 0029): bots and Expert's rollouts use lean generation, the round the
## complete list. Measured medians are about 2.6 ms and 5 ms for 20-card hands with one
## wild rank, against 0.5 ms with none; the budgets leave room for a slower machine.
func test_wild_generation_stays_inside_its_budget() -> void:
	var stream: RandomStream = RandomStream.new(SEED + 6)
	var rules: RuleSet = _configs()[0]
	var lean_times: Array[int] = []
	var full_times: Array[int] = []
	for _index: int in TIMED_HANDS:
		var counts: PackedByteArray = _hand(stream, FULL_HAND, stream.next_int(1, 2), rules)
		var mask: int = MoveReference.mask_of(counts)
		var started: int = Time.get_ticks_usec()
		MoveGenerator.generate(counts, mask, null, rules, _map, true)
		lean_times.append(Time.get_ticks_usec() - started)
		started = Time.get_ticks_usec()
		MoveGenerator.generate(counts, mask, null, rules, _map)
		full_times.append(Time.get_ticks_usec() - started)
	lean_times.sort()
	full_times.sort()
	var lean: int = lean_times[TIMED_HANDS >> 1]
	var full: int = full_times[TIMED_HANDS >> 1]
	print("Wild move generation median: lean %d usec, complete %d usec" % [lean, full])
	assert_int(lean).is_less(LEAN_BUDGET_USEC)
	assert_int(full).is_less(FULL_BUDGET_USEC)
