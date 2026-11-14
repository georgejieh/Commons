class_name MeterSource
extends Resource
## One row of the meter table: a named cause and how far it moves one meter.

@export var id: String
## RunMeters.FAMINE or RunMeters.DENUNCIATION.
@export var meter: String
## Negative values lower the meter.
@export var amount: int
