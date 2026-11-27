class_name MeterSource
extends Resource
## One row of the meter table: a named cause and how far it moves one meter.

## The cause's name.
@export var id: String
## RunMeters.FAMINE or RunMeters.DENUNCIATION: the meters are named by these strings
## throughout, so there is no enum to name.
@export var meter: String
## Negative values lower the meter.
@export var amount: int
