class_name QuotaClosing
extends RefCounted
## What a Set paid and cost as its Quota closed, for the Quota report, read from the Set's
## events (RunController.set_events) after its last round was scored: the coupons The
## Bookkeeper paid (ADR 0021), and how far Famine rose, which the log holds even when the
## rise was cut off at the top.

## The Cadre that pays coupons as a Quota closes, before the Quota pays.
const BOOKKEEPER: String = "the_bookkeeper"

## The coupons The Bookkeeper paid as the Quota closed.
var bookkeeper_paid: int = 0
## How far Famine rose as the Quota closed, counting a rise cut off at the top.
var famine_rise: int = 0


func _init(events: Array[RunEvent]) -> void:
	for event: RunEvent in events:
		if event.type == RunEvent.Type.ROUND_SCORED:
			bookkeeper_paid = 0
			famine_rise = 0
		elif event.type == RunEvent.Type.CADRE_FIRED and event.text == BOOKKEEPER:
			bookkeeper_paid += event.value
		elif event.type == RunEvent.Type.METER_CHANGED and event.text == RunMeters.FAMINE:
			famine_rise += event.value
