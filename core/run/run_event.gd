class_name RunEvent
extends RefCounted
## One thing that happened in a run. Round play arrives wrapped as ROUND events.

enum Type {
	SET_STARTED,
	DEBUFF_ADDED,
	DEALT,
	REDEALT,
	BID,
	LANDLORD_CHOSEN,
	SWAPPED,
	ROUND,
	PLAY_SCORED,
	ROUND_SCORED,
	BANKED,
	NEED_DECLARED,
	SHARE_PAID,
	SEAT_KEPT,
	SEAT_LOST,
	METER_CHANGED,
	SET_ENDED,
	## value 1 when a setback starts, 0 when it lifts; text names it.
	SETBACK,
	## A meter reached its death threshold; text names the meter.
	RUN_DIED,
	REEDUCATED,
	## value is the change; text names the cause.
	RESENTMENT,
	## A declared need was checked: value 1 when it was a lie, 0 when honest.
	AUDITED,
	## A villager's own Denunciation changed; value is the change.
	VILLAGER_DENOUNCED,
	## A family's roster status changed: value is the status, text the family.
	ROSTER_CHANGED,
	## A boss Set began: text is the boss ID.
	BOSS_CHOSEN,
	## The Purge destroyed a Cadre: text is its ID.
	CADRE_PURGED,
}

var type: Type
var seat: int
var value: int
var amount: float
var text: String
## Set only for ROUND events.
var round_event: RoundEvent
## Set only for PLAY_SCORED: the play's Grain, Rate and Zeal. amount is their product,
## times any total scale a hook set.
var grain: float = 0.0
var rate: float = 0.0
var zeal: float = 0.0


func _init(
	event_type: Type,
	acting_seat: int = Seats.NONE,
	event_value: int = 0,
	event_amount: float = 0.0,
	event_text: String = ""
) -> void:
	type = event_type
	seat = acting_seat
	value = event_value
	amount = event_amount
	text = event_text


static func wrap(event: RoundEvent) -> RunEvent:
	var wrapped: RunEvent = RunEvent.new(Type.ROUND, event.seat)
	wrapped.round_event = event
	return wrapped


## One line for golden logs.
func describe() -> String:
	if round_event != null:
		return "  " + round_event.describe()
	var line: String = "%s seat=%d value=%d" % [Type.keys()[type], seat, value]
	if amount != 0.0:
		line += " amount=%.3f" % amount
	if not text.is_empty():
		line += " " + text
	return line
