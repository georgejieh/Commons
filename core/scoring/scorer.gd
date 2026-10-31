class_name Scorer
extends RefCounted
## Scores a play as Grain × Zeal. Grain is the hand type's base plus each scored card.
## Hooks then apply additive Grain, additive Zeal and multiplicative Zeal, in that order.
## Each bomb or rocket doubles Zeal. Kickers don't score.

const DEFAULT_PARAMS: ScoreParams = preload("res://data/scoring/default_scoring.tres")
## Largest value the display can show. NaN and infinity clamp to it.
const MAX_SCORE: float = 1e300


static func score_play(
	cards: Array[CardInstance],
	pattern: Pattern,
	level: int,
	seat: int,
	is_landlord: bool,
	stack: ModifierStack,
	params: ScoreParams = DEFAULT_PARAMS
) -> ScoreBreakdown:
	var scored: Array[CardInstance] = _scored_cards(cards, pattern)
	var breakdown: ScoreBreakdown = ScoreBreakdown.new(scored.size())
	var grain: float = params.grain_for(pattern.type, level)
	breakdown.add_step(ScoreBreakdown.Step.BASE_GRAIN, grain)

	for card: CardInstance in scored:
		var base: float = params.card_grain[card.base_rank()]
		var context: CardContext = CardContext.new(seat, is_landlord, card, base)
		stack.run_card_scored(context)
		breakdown.add_step(ScoreBreakdown.Step.CARD_GRAIN, context.grain)
		grain += context.grain

	var zeal: float = params.zeal_for(pattern.type, level)
	breakdown.add_step(ScoreBreakdown.Step.BASE_ZEAL, zeal)
	var play: PlayContext = PlayContext.new(seat, is_landlord, pattern, 0.0, 0.0, 1.0)
	stack.run_play_scored(play)
	grain += play.add_grain
	zeal = (zeal + play.add_zeal) * play.mul_zeal
	breakdown.add_step(ScoreBreakdown.Step.ADD_GRAIN, play.add_grain)
	breakdown.add_step(ScoreBreakdown.Step.ADD_ZEAL, play.add_zeal)
	breakdown.add_step(ScoreBreakdown.Step.MUL_ZEAL, play.mul_zeal)
	if pattern.type == Pattern.Type.BOMB or pattern.type == Pattern.Type.ROCKET:
		zeal *= params.bomb_zeal_multiplier
		breakdown.add_step(ScoreBreakdown.Step.BOMB_ZEAL, params.bomb_zeal_multiplier)

	breakdown.grain = clamp_score(grain)
	breakdown.zeal = clamp_score(zeal)
	breakdown.total = clamp_score(grain * zeal)
	return breakdown


## The end-of-round multiplier for one side's score.
static func round_multiplier(
	finish: RoundEvent.Finish,
	went_out_first: bool,
	rules: RuleSet,
	params: ScoreParams = DEFAULT_PARAMS
) -> float:
	var multiplier: float = params.first_out_multiplier if went_out_first else 1.0
	if finish == RoundEvent.Finish.SPRING:
		multiplier *= params.spring_multiplier
	elif finish == RoundEvent.Finish.ANTI_SPRING and rules.anti_spring_doubles():
		multiplier *= params.anti_spring_multiplier
	return multiplier


static func clamp_score(value: float) -> float:
	if is_nan(value) or value > MAX_SCORE:
		return MAX_SCORE
	return maxf(value, -MAX_SCORE)


static func _scored_cards(cards: Array[CardInstance], pattern: Pattern) -> Array[CardInstance]:
	var scored: Array[CardInstance] = []
	for card: CardInstance in cards:
		if pattern.type == Pattern.Type.ROCKET or _in_body(card.base_rank(), pattern):
			scored.append(card)
	return scored


static func _in_body(rank: int, pattern: Pattern) -> bool:
	return rank >= pattern.main_rank and rank < pattern.main_rank + pattern.chain_length
