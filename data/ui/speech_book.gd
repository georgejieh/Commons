class_name SpeechBook
extends Resource
## Every table speech line, by event (P3B.8). The table picks one line per event with a
## salt it chooses, so the same salt always gives the same line.

## The events a line can answer.
const EVENTS: Array[String] = ["call", "no_call", "pass", "cards_left", "bomb", "won", "lost"]
const MOODS: Array[String] = ["calm", "eager", "sour", "sly", "tired"]

@export var lines: Array[SpeechLine] = []


func lines_for(event: String) -> Array[SpeechLine]:
	var found: Array[SpeechLine] = []
	for line: SpeechLine in lines:
		if line.event == event:
			found.append(line)
	return found


## One line for event, or null when there is none.
func pick(event: String, salt: int) -> SpeechLine:
	var found: Array[SpeechLine] = lines_for(event)
	if found.is_empty():
		return null
	return found[posmod(salt, found.size())]
