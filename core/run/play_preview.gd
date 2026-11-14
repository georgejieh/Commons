class_name PlayPreview
extends RefCounted
## What the player's chosen cards would do if played now: how the table reads them, and
## the score they would earn.

var reading: PlayReading
## 0 unless the cards form a pattern.
var score: float = 0.0
## The Grain, Rate and Zeal behind score.
var grain: float = 0.0
var rate: float = 0.0
var zeal: float = 0.0


func _init(
	play_reading: PlayReading,
	play_score: float,
	play_grain: float = 0.0,
	play_rate: float = 0.0,
	play_zeal: float = 0.0,
) -> void:
	reading = play_reading
	score = play_score
	grain = play_grain
	rate = play_rate
	zeal = play_zeal


func can_play() -> bool:
	return reading.reason == RoundState.Reason.OK
