class_name RunParams
extends Resource
## Run numbers that later systems may replace. base_need is every villager's true need.
## Meter sources live in the meter table (meters.tres).

@export var base_need: int
## Plot swaps each round, and cards the plot holds, before upgrades (P4.8).
@export var swaps_per_round: int
@export var plot_capacity: int = 4
@export var meter_max: int
