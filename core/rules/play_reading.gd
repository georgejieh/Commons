class_name PlayReading
extends RefCounted
## How a seat's chosen cards read against the table, without playing them: the reason a
## play would be refused or OK, the pattern when the cards form one, and the cards.

var reason: RoundState.Reason
## Null unless the cards form a pattern, which they can while still not beating the play.
var pattern: Pattern
## Why the cards form no pattern, when they don't.
var invalid_reason: Classification.Reason = Classification.Reason.OK
var cards: Array[CardInstance] = []
## Every reading of the cards that may be played now, strongest first (ADR 0029). The
## pattern is the first of them unless the action named another.
var readings: Array[Pattern] = []


func _init(why: RoundState.Reason) -> void:
	reason = why
