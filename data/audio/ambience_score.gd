class_name AmbienceScore
extends Resource
## The ambience beds and how they move: slow crossfades as the board changes, a
## dip under the hero effects and under voices, and the beds that hush when the player
## plays, as the struggle's crowd falls quiet.

## Every bed.
@export var beds: Array[AmbienceBed] = []
## Seconds a bed takes to fade fully in or out, on top of the board's own easing.
@export var fade_seconds: float = 4.0
## Names of the sound effects the beds dip under.
@export var duck_events: Array[String] = []
## How deep the dip goes, in decibels.
@export var duck_db: float = -8.0
## Seconds the dip takes to reach its depth.
@export var duck_attack_seconds: float = 0.08
## Seconds the dip is held after the effect starts.
@export var duck_hold_seconds: float = 0.4
## Seconds the beds take to return to full.
@export var duck_release_seconds: float = 1.5
## IDs of the beds that fall silent when the player plays a card, then come back.
@export var hush_beds: Array[String] = []
## Seconds those beds take to fall silent.
@export var hush_attack_seconds: float = 0.15
## Seconds they stay silent.
@export var hush_hold_seconds: float = 2.5
## Seconds they take to return.
@export var hush_release_seconds: float = 3.0
## The compressor on the ambience bus that the Voice bus keys, so beds dip while a
## villager speaks. The level of the voice, in decibels, above which it compresses.
@export var voice_threshold_db: float = -30.0
## How hard it compresses, as a ratio.
@export var voice_ratio: float = 6.0
## Microseconds it takes to engage.
@export var voice_attack_us: float = 2000.0
## Milliseconds it takes to let go.
@export var voice_release_ms: float = 400.0


func bed(bed_id: String) -> AmbienceBed:
	for each: AmbienceBed in beds:
		if each.id == bed_id:
			return each
	return null


## The voice-keyed compressor for the ambience bus.
func voice_duck(voice_bus: String) -> AudioEffectCompressor:
	var duck: AudioEffectCompressor = AudioEffectCompressor.new()
	duck.sidechain = voice_bus
	duck.threshold = voice_threshold_db
	duck.ratio = voice_ratio
	duck.attack_us = voice_attack_us
	duck.release_ms = voice_release_ms
	return duck
