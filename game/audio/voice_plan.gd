class_name VoicePlan
extends RefCounted
## One spoken line, worked out ahead (P3B.13): when each character of the text shows,
## and which letter sound plays when, at what pitch and volume.

## Seconds from the line's start at which each character of the shown text appears.
var reveal: PackedFloat32Array = PackedFloat32Array()
## The letter sounds, in order, with their start times, pitch scales and volumes.
var letters: PackedStringArray = PackedStringArray()
var times: PackedFloat32Array = PackedFloat32Array()
var pitches: PackedFloat32Array = PackedFloat32Array()
var volumes_db: PackedFloat32Array = PackedFloat32Array()
## Seconds until the line has finished, trailing pause included.
var length: float = 0.0
