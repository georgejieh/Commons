class_name SfxBank
extends Resource
## Every sound effect by audio event name. An event with no entry is silent.

## Every sound.
@export var sounds: Array[SfxSound] = []


## The sound for an audio event name, or null when the event has none.
func sound(id: String) -> SfxSound:
	for each: SfxSound in sounds:
		if each.id == id:
			return each
	return null
