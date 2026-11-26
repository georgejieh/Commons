class_name SpeechBook
extends Resource
## Every table speech line, by event. The table picks one line per event with a
## salt it chooses, so the same salt always gives the same line. Lines in the slogan mood
## are never picked as ordinary lines: the board's dread says them in place of one.

## The events a line can answer.
const EVENTS: Array[String] = ["call", "no_call", "pass", "cards_left", "bomb", "won", "lost"]
## The mood of a line the board's dread says in place of an ordinary one.
const SLOGAN: String = "slogan"

## Every line.
@export var lines: Array[SpeechLine] = []


## The ordinary lines for event.
func lines_for(event: String) -> Array[SpeechLine]:
	return _lines(event, false)


## The slogans said for event in place of an ordinary line.
func slogans_for(event: String) -> Array[SpeechLine]:
	return _lines(event, true)


## One line for event, or null when there is none.
func pick(event: String, salt: int) -> SpeechLine:
	var found: Array[SpeechLine] = lines_for(event)
	if found.is_empty():
		return null
	return found[posmod(salt, found.size())]


func _lines(event: String, slogans: bool) -> Array[SpeechLine]:
	var found: Array[SpeechLine] = []
	for line: SpeechLine in lines:
		if line.event == event and (line.mood == SLOGAN) == slogans:
			found.append(line)
	return found
