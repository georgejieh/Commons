class_name AmbienceBed
extends Resource
## One ambience loop under the table (P3C.8): a room, chatter, wind, a drone, paper and
## footsteps, whispers, a clock, a far crowd. Dread layers name it in their
## audio_stems by id. A bed heard on the clean board is taken away by the layers that
## name it; one silent there is brought in by them.

@export var id: String = ""
## A seamless loop: the WAV imports with its loop on the whole file.
@export var stream: AudioStream
## Runtime gain on top of the file's own level, for the mix.
@export var volume_db: float = 0.0
## Heard on the clean board, so the layers naming it take it away.
@export var on_clean_board: bool = false
## Maps a naming layer's shown weight, 0 to 1, to how far it moves the bed, 0 to 1:
## points sorted by x, as HorrorLayer.response.
@export var response: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(1, 1)])
