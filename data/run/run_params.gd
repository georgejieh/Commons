class_name RunParams
extends Resource
## Run numbers that later systems may replace. base_need is every villager's true need.
## Meter sources live in the meter table (meters.tres).

## What every villager truly needs from the Commons each round, in work points.
@export var base_need: int
## Plot swaps each round, before upgrades, in swaps.
@export var swaps_per_round: int
## Cards the private plot holds, before upgrades, in cards.
@export var plot_capacity: int = 4
## The most cards of one rank the communal deck may hold after the state store's
## exchanges (ADR 0042). With the private plot's cards a hand can hold more, and every
## count of one rank must fit CountKey.MAX_COUNT.
@export var deck_rank_most: int = 8
## The most a meter can hold, in points.
@export var meter_max: int
## Sets in a row the player may go without the landlord's seat before it costs Famine
## (ADR 0031).
@export var seat_grace_sets: int
## The most steps that cost then grows to, in steps (ADR 0031).
@export var seat_max_steps: int
