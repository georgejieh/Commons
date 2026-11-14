class_name VoiceTiming
extends Resource
## How a villager's babble is timed and pitched (P3B.13), shared by every voice. The
## same numbers render the prototype in tools/voice_proto/voice_proto.py, which the owner
## approved by ear on 2026-11-06.

## Profiles give pace in syllables per second; a syllable is about this many letters.
@export var letters_per_syllable: float = 2.6
## Pauses after these characters, in letter lengths.
@export var pauses: Dictionary[String, float] = {
	" ": 0.5, ",": 2.5, ".": 4.0, "!": 4.0, "?": 4.0, ";": 3.0, ":": 3.0
}
## The extra pause after a trailing "...", in letter lengths.
@export var trail_pause: float = 6.0
## The whole sentence drifts down by this much from its first word to its last.
@export var declination: float = 0.1
## Words this long or longer tend to carry the stress.
@export var long_word: int = 4
## Per-word pitch steps, as a range around 0, for long and short words.
@export var long_accent: Vector2 = Vector2(0.04, 0.14)
@export var short_accent: Vector2 = Vector2(-0.07, 0.04)
## Each letter's small fixed pitch wobble, as a fraction.
@export var wobble: float = 0.04
## The last word's pitch at its start (x) and end (y), by sentence ending.
@export var endings: Dictionary[String, Vector2] = {
	".": Vector2(1.0, 0.85),
	"?": Vector2(1.0, 1.35),
	"!": Vector2(1.18, 1.0),
	"...": Vector2(0.95, 0.6),
}
## Each ending's loudness (x) and pace (y) scale.
@export var ending_drive: Dictionary[String, Vector2] = {
	".": Vector2(1.0, 1.0),
	"?": Vector2(1.0, 1.0),
	"!": Vector2(1.25, 1.2),
	"...": Vector2(0.8, 0.75),
}
## Mood to pitch range (x), pace (y), loudness (z) and overall pitch (w) scales.
## "slogan" speaks flat: no word steps, no wobble, no ending shape.
@export var moods: Dictionary[String, Vector4] = {
	"": Vector4(1.0, 1.0, 1.0, 1.0),
	"calm": Vector4(0.8, 0.95, 0.9, 1.0),
	"eager": Vector4(1.3, 1.15, 1.1, 1.05),
	"sour": Vector4(0.7, 0.95, 0.95, 0.93),
	"sly": Vector4(1.1, 0.9, 0.85, 1.0),
	"tired": Vector4(0.6, 0.8, 0.8, 0.95),
	"slogan": Vector4(0.0, 0.9, 1.0, 1.0),
}
## At full dread the voice slows by this fraction, narrows its pitch range by this
## fraction, and quiets by this fraction.
@export var dread_slow: float = 0.3
@export var dread_narrow: float = 0.5
@export var dread_quiet: float = 0.4
