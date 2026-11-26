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
## The share of true need a lie adds, for each level.
@export var lie_share: PackedFloat32Array
## The least a lie adds to true need, in work points.
@export var lie_floor: int
