class_name CardContext
extends RefCounted
## Passed to the card scored hook.

## The seat whose card is being scored.
var seat: int
## True when that seat is the round's landlord.
var is_landlord: bool
## The round's landlord, or Seats.NONE outside a round, so the stack can tell the seat's
## side (ADR 0039).
var landlord: int = Seats.NONE
## The card being scored.
var card: CardInstance
## This card's Grain, to edit.
var grain: float
## The card's own Grain before any hook: its printed value, raised if it is Model. An
## effect that doubles a card's own Grain adds this, so it never doubles another hook's
## flat Grain and the order of hooks does not matter.
var own_grain: float
## The card's printed Grain, before Model raised it (ADR 0032).
var printed_grain: float


func _init(
	seat_value: int,
	is_landlord_value: bool,
	card_value: CardInstance,
	grain_value: float,
) -> void:
	seat = seat_value
	is_landlord = is_landlord_value
	card = card_value
	grain = grain_value
	own_grain = grain_value
	printed_grain = grain_value
