class_name PlayPreview
extends RefCounted
## What the player's chosen cards would do if played now: how the table reads them, and
## the score they would earn.

## How the table reads the chosen cards, with the reason they cannot be played if so.
var reading: PlayReading
## 0 unless the cards form a pattern.
var score: float = 0.0
## The Grain behind score.
var grain: float = 0.0
## The Rate behind score.
var rate: float = 0.0
## The Zeal behind score.
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


## True when the chosen cards are a legal play now.
func can_play() -> bool:
	return reading.reason == RoundState.Reason.OK
