class_name Scorer
extends RefCounted
## Scores a play as Grain × Rate × Zeal (ADR 0020). Grain is the scored cards' values
## plus additive Grain from hooks; kickers don't score. A Model card's own value is
## raised by the data's percent, and a Sheaf card's by the data's Grain, before any hook
## sees it, for whoever scores it (ADR 0021, ADR 0041); each scored Pennant card gives the
## play Zeal before the hooks run, and each scored Surplus card is listed for the loop to
## pay. Rate comes from the hand type and its level, then a hook's share of it
## rounded up (ADR 0023), then a hook's Rate cap. Zeal starts at 1, takes the Pennant
## cards' Zeal, then changes through hooks: additive Zeal, then multiplicative Zeal, never
## below the data's minimum.
## With a wild card standing in (ADR 0029) Grain still comes from the printed cards, and a
## card is body or kicker by where the reading puts it (PlayPlacement); Rate comes from
## the reading's type.

const DEFAULT_PARAMS: ScoreParams = preload("res://data/scoring/default_scoring.tres")
## Largest value the display can show. NaN and infinity clamp to it.
const MAX_SCORE: float = 1e300
## Every play's Zeal before hooks change it.
const STARTING_ZEAL: float = 1.0
const PERCENT: float = 100.0


static func score_play(
	cards: Array[CardInstance],
	pattern: Pattern,
	level: int,
	seat: int,
	is_landlord: bool,
	stack: ModifierStack,
	params: ScoreParams = DEFAULT_PARAMS,
	plays_before: int = 0,
	facts: PlayFacts = null,
	record: bool = false
) -> ScoreBreakdown:
	# A real play records each change for the table to act out; a preview doesn't.
	var trail: ScoreTrail = ScoreTrail.new() if record else null
	var breakdown: ScoreBreakdown = ScoreBreakdown.new()
	var play: PlayContext = PlayContext.new(seat, is_landlord, pattern, 0.0, 0.0, 1.0)
	play.plays_before = plays_before
	if facts != null:
		play.landlord = facts.landlord
		play.cards_left = facts.cards_left
		play.seat_plays = facts.seat_plays
		play.seat_grain = facts.seat_grain
		play.year = facts.year
	play.card_grain = params.card_grain
	var card_grain: float = _score_cards(cards, play, stack, params, trail, breakdown)
	stack.run_play_scored(play, trail)
	breakdown.stamps_resented = play.stamps_resented
	_total(card_grain + play.add_grain, play, level, params, breakdown)
	if trail != null:
		var base_rate: float = params.rate_for(pattern.type, HandLevels.FIRST_LEVEL)
		trail.finish(base_rate, params.rate_for(pattern.type, level), params.min_zeal)
		breakdown.trail = trail.steps
	return breakdown


## A scored card's Grain before any hook, from its printed Grain and its enhancement: a
## Model card's at the data's percent, a Sheaf card's with the data's Grain added.
static func marked_grain(card: CardInstance, printed: float, params: ScoreParams) -> float:
	match card.enhancement_id():
		CardInstance.MODEL:
			return printed * params.model_grain_percent / PERCENT
		CardInstance.SHEAF:
			return printed + params.sheaf_grain
	return printed


## A hand's Rate at its level once a hook's share of it (ADR 0023), rounded up, and a cap
## are applied.
static func rate_after(level_rate: float, percent: int, cap: float) -> float:
	var rate: float = level_rate
	if percent != PERCENT:
		rate = ceilf(rate * percent / PERCENT)
	return minf(rate, cap)


## The end-of-round multiplier for one side's score. Spring and anti-spring reward only
## the side that won.
static func round_multiplier(
	finish: RoundEvent.Finish,
	went_out_first: bool,
	side_won: bool,
	rules: RuleSet,
	params: ScoreParams = DEFAULT_PARAMS
) -> float:
	var multiplier: float = params.first_out_multiplier if went_out_first else 1.0
	if not side_won:
		return multiplier
	if finish == RoundEvent.Finish.SPRING:
		multiplier *= params.spring_multiplier
	elif finish == RoundEvent.Finish.ANTI_SPRING and rules.anti_spring_doubles():
		multiplier *= params.anti_spring_multiplier
	return multiplier


## Applies a round multiplier, keeping the result in range.
static func round_total(score: float, multiplier: float) -> float:
	return clamp_score(score * multiplier)


static func clamp_score(value: float) -> float:
	if is_nan(value) or value > MAX_SCORE:
		return MAX_SCORE
	return maxf(value, -MAX_SCORE)


## Per card, in order, true when the reading puts it in the body, which scores Grain.
static func body_flags(cards: Array[CardInstance], pattern: Pattern) -> Array[bool]:
	var flags: Array[bool] = []
	for rank: int in PlayPlacement.stands_for(cards, pattern):
		flags.append(PlayPlacement.is_body(rank, pattern))
	return flags


## Scores the play's cards: each body card's printed Grain, its mark and the card hooks,
## in play order. Fills the play's body and kicker cards and gives it the Pennant cards'
## Zeal; the scored Surplus cards go on the breakdown. Returns the cards' Grain.
static func _score_cards(
	cards: Array[CardInstance],
	play: PlayContext,
	stack: ModifierStack,
	params: ScoreParams,
	trail: ScoreTrail,
	breakdown: ScoreBreakdown
) -> float:
	var body: Array[bool] = body_flags(cards, play.pattern)
	var body_cards: PackedByteArray = PackedByteArray()
	var kicker_cards: PackedByteArray = PackedByteArray()
	for index: int in cards.size():
		if body[index]:
			body_cards.append(cards[index].base_rank())
		else:
			kicker_cards.append(cards[index].base_rank())
	play.body_cards = body_cards
	play.kicker_cards = kicker_cards
	var grain: float = 0.0
	for index: int in cards.size():
		if not body[index]:
			continue
		var card: CardInstance = cards[index]
		var printed: float = params.card_grain[card.base_rank()]
		var base: float = marked_grain(card, printed, params)
		var enhancement: String = card.enhancement_id()
		if trail != null:
			trail.card(card.id(), printed)
			trail.mark(card.id(), enhancement, base - printed)
		if enhancement == CardInstance.PENNANT:
			play.add_zeal += params.pennant_zeal
			if trail != null:
				trail.mark_zeal(card.id(), enhancement, params.pennant_zeal)
		elif enhancement == CardInstance.SURPLUS:
			breakdown.surplus_cards.append(card.id())
		var context: CardContext = CardContext.new(play.seat, play.is_landlord, card, base)
		context.printed_grain = printed
		context.landlord = play.landlord
		stack.run_card_scored(context, trail)
		grain += context.grain
	play.grain = grain
	return grain


## Sets the breakdown's figures once the play hooks have run: Rate from the hand type at
## its level, its share and its cap, Zeal never below the data's floor, and the total.
static func _total(
	grain: float, play: PlayContext, level: int, params: ScoreParams, breakdown: ScoreBreakdown
) -> void:
	var level_rate: float = params.rate_for(play.pattern.type, level)
	var rate: float = rate_after(level_rate, play.rate_percent, INF)
	if rate > play.rate_cap:
		rate = play.rate_cap
	var zeal: float = maxf(params.min_zeal, (STARTING_ZEAL + play.add_zeal) * play.mul_zeal)
	breakdown.grain = clamp_score(grain)
	breakdown.rate = clamp_score(rate)
	breakdown.zeal = clamp_score(zeal)
	breakdown.total = clamp_score(grain * rate * zeal * play.total_scale)
