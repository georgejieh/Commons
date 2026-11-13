class_name ScoreParams
extends Resource
## Every scoring number. hand_rate holds max_level rows for each Pattern.Type
## (ADR 0019).

@export var max_level: int
## Each hand type's Rate by level, the multiplier that comes from the hand type alone.
@export var hand_rate: Array[int]
## Each base rank's Grain.
@export var card_grain: Array[int]
## No play scores with less Zeal than this, so a Zeal debuff never zeroes a hand.
@export var min_zeal: float = 1.0
@export var first_out_multiplier: float
@export var spring_multiplier: float
@export var anti_spring_multiplier: float


## type is a Pattern.Type value. level runs from 1 to max_level.
func rate_for(type: int, level: int) -> int:
	assert(level >= 1 and level <= max_level)
	return hand_rate[type * max_level + level - 1]
