class_name VoicePlan
extends RefCounted
## One spoken line, worked out ahead: when each character of the text shows,
## and which letter sound plays when, at what pitch and volume.

## Seconds from the line's start at which each character of the shown text appears.
var reveal: PackedFloat32Array = PackedFloat32Array()
## The letter sounds, in order: one lower case letter per sound to play.
var letters: PackedStringArray = PackedStringArray()
## Seconds from the line's start at which each letter sound starts, parallel to letters.
var times: PackedFloat32Array = PackedFloat32Array()
## The pitch scale each letter sound plays at, parallel to letters.
var pitches: PackedFloat32Array = PackedFloat32Array()
## The volume in decibels each letter sound plays at, parallel to letters.
var volumes_db: PackedFloat32Array = PackedFloat32Array()
## Seconds until the line has finished, trailing pause included.
var length: float = 0.0
