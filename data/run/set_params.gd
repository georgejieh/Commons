class_name SetParams
extends Resource
## The run's shape: Years, Set targets as a curve, rounds per Set and rewards. The curve
## holds one target per Set in play order, small, large and boss for each Year.

@export var years: int
@export var max_rounds: int
@export var targets: Array[float]
## Coupons for meeting a target, indexed by RunState.SetType.
@export var reward_coupons: Array[int]
