class_name Scorer
extends RefCounted
## Scores a play as Grain × Rate × Zeal (ADR 0020). Grain is the scored cards' values
## plus additive Grain from hooks; kickers don't score. A Model card's own value is
## raised by the data's percent before any hook sees it, for whoever scores it
## (ADR 0021). Rate comes from the hand type and its level, then a hook's share of it
## rounded up (ADR 0023), then a hook's Rate cap. Zeal starts at 1 and changes only
## through hooks: additive Zeal, then multiplicative Zeal, never below the data's minimum.
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
	facts: PlayFacts = null
) -> ScoreBreakdown:
	var body: Array[bool] = body_flags(cards, pattern)
	var scored: int = 0
	var kicker_cards: PackedByteArray = PackedByteArray()
	var body_cards: PackedByteArray = PackedByteArray()
	for index: int in cards.size():
		if body[index]:
			scored += 1
			body_cards.append(cards[index].base_rank())
		else:
			kicker_cards.append(cards[index].base_rank())
	var breakdown: ScoreBreakdown = ScoreBreakdown.new(scored)
	var grain: float = 0.0
	for index: int in cards.size():
		var card: CardInstance = cards[index]
		if body[index]:
			var printed: float = params.card_grain[card.base_rank()]
			var base: float = printed
			if card.enhancement_id() == CardInstance.MODEL:
				base = base * params.model_grain_percent / PERCENT
			var context: CardContext = CardContext.new(seat, is_landlord, card, base)
			context.printed_grain = printed
			context.landlord = Seats.NONE if facts == null else facts.landlord
			stack.run_card_scored(context)
			breakdown.add_step(ScoreBreakdown.Step.CARD_GRAIN, context.grain)
			grain += context.grain

	var play: PlayContext = PlayContext.new(seat, is_landlord, pattern, 0.0, 0.0, 1.0)
	play.plays_before = plays_before
	if facts != null:
		play.landlord = facts.landlord
		play.cards_left = facts.cards_left
		play.seat_plays = facts.seat_plays
		play.seat_grain = facts.seat_grain
		play.year = facts.year
	play.grain = grain
	play.card_grain = params.card_grain
	play.kicker_cards = kicker_cards
	play.body_cards = body_cards
	stack.run_play_scored(play)
	breakdown.stamps_resented = play.stamps_resented
	grain += play.add_grain
	breakdown.add_step(ScoreBreakdown.Step.ADD_GRAIN, play.add_grain)

	var rate: float = params.rate_for(pattern.type, level)
	if play.rate_percent != PERCENT:
		rate = ceilf(rate * play.rate_percent / PERCENT)
	breakdown.add_step(ScoreBreakdown.Step.RATE, rate)
	if rate > play.rate_cap:
		rate = play.rate_cap
		breakdown.add_step(ScoreBreakdown.Step.RATE_CAP, play.rate_cap)

	var zeal: float = maxf(params.min_zeal, (STARTING_ZEAL + play.add_zeal) * play.mul_zeal)
	breakdown.add_step(ScoreBreakdown.Step.ADD_ZEAL, play.add_zeal)
	breakdown.add_step(ScoreBreakdown.Step.MUL_ZEAL, play.mul_zeal)

	breakdown.grain = clamp_score(grain)
	breakdown.rate = clamp_score(rate)
	breakdown.zeal = clamp_score(zeal)
	breakdown.total = clamp_score(grain * rate * zeal * play.total_scale)
	return breakdown


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


## True when a card of a play with no stand-in scores Grain: its body, not its kickers.
## A play with a stand-in places its cards together, through body_flags.
static func is_scored(card: CardInstance, pattern: Pattern) -> bool:
	return PlayPlacement.is_body(card.base_rank(), pattern)


## Per card, in order, true when the reading puts it in the body, which scores Grain.
static func body_flags(cards: Array[CardInstance], pattern: Pattern) -> Array[bool]:
	var flags: Array[bool] = []
	for rank: int in PlayPlacement.stands_for(cards, pattern):
		flags.append(PlayPlacement.is_body(rank, pattern))
	return flags
