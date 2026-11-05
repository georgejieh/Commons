class_name RunParams
extends Resource
## Run numbers that later systems replace. base_need stands in for each villager's true
## need until P4.3, swaps_per_round for the plot's upgrades until P4.8, and the missed
## target's Famine is the one meter source until P4.1 adds the rest.

@export var base_need: int
@export var swaps_per_round: int
@export var famine_on_missed_target: int
@export var meter_max: int
