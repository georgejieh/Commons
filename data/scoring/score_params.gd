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


func grain_for(type: Pattern.Type, level: int) -> int:
	return hand_grain[type * max_level + level - 1]


func zeal_for(type: Pattern.Type, level: int) -> int:
	return hand_zeal[type * max_level + level - 1]
