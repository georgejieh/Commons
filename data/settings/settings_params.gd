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
## The card back design chosen (ADR 0025): cosmetic, per player.
@export var card_back: String = "sunrise"
## The text size chosen (ADR 0034): an index into text_scales, 0 for Standard.
@export var text_size: int = 0

@export_group("Text size")
## What each text size multiplies every font size by: Standard, Large, Largest. Not saved.
@export var text_scales: Array[float] = [1.0, 1.15, 1.3]
## The least font size, in canvas pixels, anything the player reads is set at. Not saved.
@export var least_text_px: int = 14
## Display type holds (ADR 0034): a base size this large or larger, the title and
## headline steps and the ending's title, does not grow. Not saved.
@export var display_text_px: int = 40
