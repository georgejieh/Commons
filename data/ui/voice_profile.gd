class_name VoiceProfile
extends Resource
## One villager voice (P3B.13): the numbers the syllable bank is rendered from, by
## formant synthesis in tools/voice_proto/render_bank.py. No TTS and no recordings.

## Base pitch in Hz.
@export var pitch: float = 140.0
## Formant scale: below 1 sounds larger and darker, above 1 smaller and brighter.
@export var tone: float = 1.0
## Syllables per second.
@export var pace: float = 5.0
## 0 is a clean voice, 1 a rough one.
@export_range(0.0, 1.0) var roughness: float = 0.1
