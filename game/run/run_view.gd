class_name RunView
extends RefCounted
## A read-only view of a run's state for screens: where the run stands, its meters and
## coupons by getter, and anything that could be changed handed out as a copy, so a
## screen reads the run as it is now without copying the whole state. GDScript has no
## read-only references, so this class's own code is the guard: it never hands out the
## state itself, its inventory, its books, or any array or dictionary of it.
## RunController builds one over each run it attaches, as controller.run; a test may
## build one over any state.

var _state: RunState


func _init(state: RunState) -> void:
	_state = state


## The Year in play, from 1.
func year() -> int:
	return _state.year


## The Set's place in its Year, from 0.
func set_index() -> int:
	return _state.set_index


## Whether the Set is the Year's small, large or boss Quota.
func set_type() -> RunState.SetType:
	return _state.set_type


## The round in play's place in its Set, from 0; between rounds, the next one's.
func round_index() -> int:
	return _state.round_index


## The work points the Set has made towards its target.
func set_progress() -> float:
	return _state.set_progress


## The coupons the player holds.
func coupons() -> int:
	return _state.coupons


## The village's Resentment of the player, 0 to 100.
func resentment() -> int:
	return _state.resentment


## The Famine meter.
func famine() -> int:
	return _state.famine


## The Denunciation meter.
func denunciation() -> int:
	return _state.denunciation


## The seat that holds the landlord's seat, or Seats.NONE before it is bid for.
func landlord_seat() -> int:
	return _state.landlord_seat


## What the Commons holds for the round's split.
func commons_pool() -> int:
	return _state.commons_pool


## The seed the run was started from.
func run_seed() -> int:
	return _state.run_seed


## The Quotas in a row the player ended without holding the landlord's seat (ADR 0031).
func seatless_sets() -> int:
	return _state.seatless_sets


## How many entries the family's file holds (ADR 0022).
func file_entries() -> int:
	return _state.identity.file_entries


## The family ID in each seat, a copy.
func table() -> Array[String]:
	return _state.table.duplicate()


## The held Cadres' IDs in slot order, a copy.
func held_cadres() -> Array[String]:
	return _state.inventory.cadres.duplicate()


## The private plot's cards, each a copy.
func plot() -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for card: CardInstance in _state.inventory.plot:
		cards.append(card.snapshot())
	return cards


## What the player has seen each villager family do this run, a copy.
func observations() -> Observations:
	return Observations.from_dict(_state.observations.to_dict())


## True when a figure went dark in this run (ADR 0022).
func is_dark(figure: String) -> bool:
	return _state.books.is_dark(figure)


## The figures gone dark, in the order they went, a copy.
func dark_figures() -> Array[String]:
	return _state.books.dark.duplicate()
