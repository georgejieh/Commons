class_name SettingsParams
extends Resource
## Default player settings. A player's changes are saved over these.

## Linear volume per audio bus, 0 to 1.
@export var music_volume: float = 0.8
@export var effects_volume: float = 0.8
@export var voice_volume: float = 0.8
## Scales or disables shake, hit-stop and other motion (P3B.6).
@export var reduced_motion: bool = false
