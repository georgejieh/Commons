class_name PersonalityTable
extends Resource
## Maps Low, Mid and High to numbers. Each array has one value per Personality.Level.

## Added to the cards at which a landlord counts as running away.
@export var bomb_aggression: PackedFloat32Array
## The chance of passing on a teammate's play.
@export var cooperation: PackedFloat32Array
## The chance of declaring true need.
@export var honesty: PackedFloat32Array
## Taken off the bid thresholds.
@export var ambition: PackedFloat32Array
## Score added, per point of memory, for answering a seat.
@export var grudge: PackedFloat32Array
## A lie adds this share of true need, plus at least lie_floor.
@export var lie_share: float
@export var lie_floor: int
