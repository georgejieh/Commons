class_name RoundEvent
extends RefCounted
## One domain event. Presentation reads these and never reaches into a round. Bots get
## a SeatView instead.

enum Type { ROUND_STARTED, KITTY_TAKEN, PLAYED, PASSED, TRICK_WON, ANNOUNCED, ROUND_ENDED }
enum Finish { NORMAL, SPRING, ANTI_SPRING }

var type: Type
var seat: int
## The cards played or taken. Empty for every other event.
var card_ids: Array[int]
var pattern: Pattern
## Cards left for ANNOUNCED. A Finish for ROUND_ENDED.
var value: int


func _init(
	event_type: Type,
	event_seat: int,
	cards: Array[int] = [],
	played: Pattern = null,
	event_value: int = 0
) -> void:
	type = event_type
	seat = event_seat
	card_ids = cards
	pattern = played
	value = event_value


## One stable line for golden logs.
func describe() -> String:
	var line: String = "%s seat=%d" % [Type.keys()[type], seat]
	if not card_ids.is_empty():
		var sorted: Array[int] = card_ids.duplicate()
		sorted.sort()
		line += " cards=%s" % str(sorted)
	if pattern != null:
		line += " pattern=%s main=%d" % [Pattern.Type.keys()[pattern.type], pattern.main_rank]
		line += " chain=%d kickers=%s" % [pattern.chain_length, str(Array(pattern.kicker_ranks))]
	if type == Type.ANNOUNCED or type == Type.ROUND_ENDED:
		line += " value=%d" % value
	return line
