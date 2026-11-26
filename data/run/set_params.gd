class_name SetParams
extends Resource
## The run's shape: Years, Set targets as a curve, rounds per Set and rewards. The curve
## holds one target per Set in play order, small, large and boss for each Year.

## How many Years the run lasts.
@export var years: int
## The most rounds a Set can last before it ends.
@export var max_rounds: int
## The target of each Set, in work points.
@export var targets: Array[float]
## Coupons for meeting a target, indexed by RunState.SetType.
@export var reward_coupons: Array[int]
## A met Quota is overfulfilled by one step for each this many percent above its target.
@export var over_step_percent: int = 25
## The most steps a Quota can be overfulfilled by.
@export var over_max_steps: int = 4
## The coupons each step of overfulfilment pays.
@export var over_bonus_coupons: int = 1
## How much each step raises every later target, in percent of its base, added across
## the run.
@export var norm_percent_per_step: int = 3
