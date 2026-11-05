class_name MeterBands
extends Resource
## One meter's thresholds. A value at or above a threshold is in that band. A setback
## fires on the way up through mid and re-arms only once the meter falls below
## mid - rearm_margin, so a meter hovering at mid triggers it once.

enum Band { CALM, LOW, MID, HIGH, DEATH }

@export var low: int = 25
@export var mid: int = 50
@export var high: int = 75
## Reaching this ends the run.
@export var death: int = 100
@export var rearm_margin: int = 5


func band(value: int) -> Band:
	if value >= death:
		return Band.DEATH
	if value >= high:
		return Band.HIGH
	if value >= mid:
		return Band.MID
	if value >= low:
		return Band.LOW
	return Band.CALM


func rearms_at(value: int) -> bool:
	return value < mid - rearm_margin
