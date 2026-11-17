class_name SetParams
extends Resource
## The run's shape: Years, Set targets as a curve, rounds per Set and rewards. The curve
## holds one target per Set in play order, small, large and boss for each Year.

@export var years: int
@export var max_rounds: int
@export var targets: Array[float]
## Coupons for meeting a target, indexed by RunState.SetType.
@export var reward_coupons: Array[int]
## A met Quota is overfulfilled by one step for each this many percent above its target,
## up to over_max_steps. Each step pays over_bonus_coupons more and raises the norm: every
## later target by norm_percent_per_step percent of its base, added across the run.
@export var over_step_percent: int = 25
@export var over_max_steps: int = 4
@export var over_bonus_coupons: int = 1
@export var norm_percent_per_step: int = 3
