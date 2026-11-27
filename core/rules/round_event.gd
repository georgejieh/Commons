class_name RoundEvent
extends RefCounted
## One domain event. Presentation reads these and never reaches into a round. Bots get
## a SeatView instead.

## What happened: the round began, the kitty was taken, a play, a pass, a trick won, a
## seat's call of its few cards left, or the round's end.
enum Type { ROUND_STARTED, KITTY_TAKEN, PLAYED, PASSED, TRICK_WON, ANNOUNCED, ROUND_ENDED }
## How a round ended: normally, as a Spring (the landlord won before a peasant played), or
## as an Anti-Spring (the peasants won with the landlord having played once).
enum Finish { NORMAL, SPRING, ANTI_SPRING }

## Which event this is.
var type: Type
## The seat the event is about.
var seat: int
## The cards played or taken. Empty for every other event.
var card_ids: Array[int]
## Copies of the played cards, because scoring reads their enhancements and stamps.
var cards: Array[CardInstance] = []
## The play, for PLAYED; null for the other events.
var pattern: Pattern
## Cards left for ANNOUNCED. A Finish for ROUND_ENDED.
var value: int


func _init(
	event_type: Type,
	event_seat: int,
	ids: Array[int] = [],
	played: Pattern = null,
	event_value: int = 0
) -> void:
	type = event_type
	seat = event_seat
	card_ids = ids
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
		if not pattern.spent.is_empty():
			line += " spent=%s" % str(Array(pattern.spent))
	if type == Type.ANNOUNCED or type == Type.ROUND_ENDED:
		line += " value=%d" % value
	return line
