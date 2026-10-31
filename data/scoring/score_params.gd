class_name ScoreParams
extends Resource
## Every scoring number. Hand tables hold max_level rows for each Pattern.Type.

@export var max_level: int
@export var hand_grain: Array[int]
@export var hand_zeal: Array[int]
@export var card_grain: Array[int]
@export var bomb_zeal_multiplier: float
@export var first_out_multiplier: float
@export var spring_multiplier: float
@export var anti_spring_multiplier: float


## type is a Pattern.Type value. level runs from 1 to max_level.
func grain_for(type: int, level: int) -> int:
	assert(level >= 1 and level <= max_level)
	return hand_grain[type * max_level + level - 1]


## type is a Pattern.Type value. level runs from 1 to max_level.
func zeal_for(type: int, level: int) -> int:
	assert(level >= 1 and level <= max_level)
	return hand_zeal[type * max_level + level - 1]
