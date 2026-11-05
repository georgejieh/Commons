class_name RunParams
extends Resource
## Run numbers that later systems replace. base_need stands in for each villager's true
## need until P4.3 and swaps_per_round for the plot's upgrades until P4.8. Meter sources
## live in the meter table (meters.tres).

@export var base_need: int
@export var swaps_per_round: int
@export var meter_max: int
