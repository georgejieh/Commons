class_name PlayPreview
extends RefCounted
## What the player's chosen cards would do if played now: how the table reads them, and
## the score they would earn.

var reading: PlayReading
## 0 unless the cards form a pattern.
var score: float = 0.0


func _init(play_reading: PlayReading, play_score: float) -> void:
	reading = play_reading
	score = play_score


func can_play() -> bool:
	return reading.reason == RoundState.Reason.OK
