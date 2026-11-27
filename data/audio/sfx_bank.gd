class_name SfxBank
extends Resource
## Every sound effect by audio event name (P3C.8). An event with no entry is silent.

@export var sounds: Array[SfxSound] = []
## Meter values whose upward crossing plays the meter sound. Placeholder marks until
## P4.1 brings the real low, mid and high thresholds.
@export var meter_marks: Array[int] = [25, 50, 75]


func sound(id: String) -> SfxSound:
	for each: SfxSound in sounds:
		if each.id == id:
			return each
	return null
