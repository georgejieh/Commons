class_name RunParams
extends Resource
## Run numbers that later systems may replace. base_need is every villager's true need.
## Meter sources live in the meter table (meters.tres).

@export var base_need: int
## Plot swaps each round, and cards the plot holds, before upgrades (P4.8).
@export var swaps_per_round: int
@export var plot_capacity: int = 4
## The most cards of one rank the communal deck may hold after the state store's
## exchanges (ADR 0042). With the private plot's cards a hand can hold more, and every
## count of one rank must fit CountKey.MAX_COUNT.
@export var deck_rank_most: int = 8
@export var meter_max: int
## Sets in a row the player may go without the landlord's seat before it costs Famine,
## and the most steps that cost then grows to (ADR 0031).
@export var seat_grace_sets: int
@export var seat_max_steps: int
