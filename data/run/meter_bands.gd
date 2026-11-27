class_name MeterBands
extends Resource
## One meter's thresholds. A value at or above a threshold is in that band. A setback
## fires on the way up through mid and re-arms only once the meter falls below
## mid - rearm_margin, so a meter hovering at mid triggers it once.

## Where a meter's value sits against its thresholds, from CALM below low to DEATH.
enum Band { CALM, LOW, MID, HIGH, DEATH }

## The value at which a meter enters the low band.
@export var low: int = 25
## The value at which a meter enters the mid band, where its setback fires.
@export var mid: int = 50
## The value at which a meter enters the high band.
@export var high: int = 75
## Reaching this ends the run.
@export var death: int = 100
## How far below mid a meter must fall before its setback fires again.
@export var rearm_margin: int = 5


## The band a meter value sits in.
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


## The least value in the band.
func least(of_band: Band) -> int:
	match of_band:
		Band.LOW:
			return low
		Band.MID:
			return mid
		Band.HIGH:
			return high
		Band.DEATH:
			return death
	return 0


## The values a meter rises past into a worse band: the low, mid and high thresholds.
func marks() -> Array[int]:
	return [low, mid, high]


## True when a meter at this value has fallen far enough below mid to fire its setback
## again.
func rearms_at(value: int) -> bool:
	return value < mid - rearm_margin
