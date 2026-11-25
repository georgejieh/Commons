class_name ScoreParams
extends Resource
## Every scoring number. hand_rate holds max_level rows for each Pattern.Type
## (ADR 0020).

@export var max_level: int
## Each hand type's Rate by level, the multiplier that comes from the hand type alone.
@export var hand_rate: Array[int]
## Each base rank's Grain.
@export var card_grain: Array[int]
## A Model card's Grain, in percent of its rank's (ADR 0021).
@export var model_grain_percent: int = 200
## A Sheaf card's Grain added to its rank's, Zeal a scored Pennant card gives its play,
## and the coupons a Surplus card pays the player who scores it, at most so many a round
## (ADR 0041).
@export var sheaf_grain: int = 10
@export var pennant_zeal: float = 0.2
@export var surplus_coupons: int = 1
@export var surplus_round_most: int = 2
## No play scores with less Zeal than this, so a Zeal debuff never zeroes a hand.
@export var min_zeal: float = 1.0
@export var first_out_multiplier: float
@export var spring_multiplier: float
@export var anti_spring_multiplier: float


## type is a Pattern.Type value. level runs from 1 to max_level.
func rate_for(type: int, level: int) -> int:
	assert(level >= 1 and level <= max_level)
	return hand_rate[type * max_level + level - 1]
