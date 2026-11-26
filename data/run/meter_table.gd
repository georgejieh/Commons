class_name MeterTable
extends Resource
## Every way the run's two meters move, and where their bands and setbacks sit.

## The Famine meter's bands.
@export var famine: MeterBands
## The Denunciation meter's bands.
@export var denunciation: MeterBands
## Every way a meter moves, each by its ID.
@export var sources: Array[MeterSource] = []
## Store slots lost while rationing is in force.
@export var rationing_shop_cut: int = 1


func source(id: String) -> MeterSource:
	for row: MeterSource in sources:
		if row.id == id:
			return row
	return null


func bands(meter: String) -> MeterBands:
	return famine if meter == RunMeters.FAMINE else denunciation
