class_name SfxSound
extends Resource
## One sound effect (P3C.8): the audio event it answers and its takes. Takes play
## round-robin, so a frequent sound never repeats the same recording twice in a row.

@export var id: String = ""
@export var streams: Array[AudioStream] = []
## Runtime gain on top of the file's own level, for the mix.
@export var volume_db: float = 0.0
## Each play shifts pitch by up to this many semitones either way. Cosmetic only.
@export var pitch_semitones: float = 0.0
## How many copies may overlap before the oldest is cut.
@export var voices: int = 2
