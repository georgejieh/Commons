class_name SettingsParams
extends Resource
## Default player settings. A player's changes are saved over these.

## Linear volume per audio bus, 0 to 1.
@export var music_volume: float = 0.8
@export var effects_volume: float = 0.8
@export var voice_volume: float = 0.8
## Scales or disables shake, hit-stop and other motion (P3B.6).
@export var reduced_motion: bool = false
## The full-screen print and grain pass (P3B.7). Off is the low-quality setting.
@export var post_process: bool = true
## Scales every dread layer, 0 (the clean board) to 1 (P3B.12).
@export var horror_intensity: float = 1.0
## Turns off every flicker and the lamp's flutter (P3B.12).
@export var no_flash: bool = false
## Set once the first-launch content note has been read.
@export var content_note_seen: bool = false
