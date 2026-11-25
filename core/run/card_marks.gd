class_name CardMarks
extends RefCounted
## The marks saved on deck cards, so a stamp or an enhancement outlasts its round (ADR
## 0021, ADR 0041). Every deal builds the deck fresh, and apply() puts the saved marks
## back on it. A plot card carries its own marks, saved with the plot; one swapped into
## the hand is a copy, and a mark made on that copy reaches the plot's card by its ID (ADR
## 0038). A deck card a swap took out keeps its saved marks for the next deal. stamp()
## and enhance() are the only ways to mark a card for the run: both change the card
## through CardModifiers and save it. A card holds one enhancement at a time, so a new
## one replaces the old.

## Deck card ID to the seat whose stamp it carries, and to its enhancement ID. An
## unmarked card has no entry.
var stamps: Dictionary[int, int] = {}
var enhancements: Dictionary[int, String] = {}


## JSON keys are text, so IDs come back from it as strings.
static func from_dict(data: Dictionary) -> CardMarks:
	var marks: CardMarks = CardMarks.new()
	var stamp_data: Dictionary = data["stamps"]
	for key: Variant in stamp_data:
		marks.stamps[str(key).to_int()] = int(stamp_data[key])
	var enhancement_data: Dictionary = data["enhancements"]
	for key: Variant in enhancement_data:
		marks.enhancements[str(key).to_int()] = str(enhancement_data[key])
	return marks


## True when data has the saved shape: two maps of card IDs, to seats and to IDs.
static func is_valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var data: Dictionary = value
	if not data.get("stamps") is Dictionary or not data.get("enhancements") is Dictionary:
		return false
	var stamp_data: Dictionary = data["stamps"]
	for key: Variant in stamp_data:
		var seat: Variant = stamp_data[key]
		if not str(key).is_valid_int() or not (seat is int or seat is float):
			return false
	var enhancement_data: Dictionary = data["enhancements"]
	for key: Variant in enhancement_data:
		if not str(key).is_valid_int() or not enhancement_data[key] is String:
			return false
	return true


func to_dict() -> Dictionary:
	var stamp_data: Dictionary[String, int] = {}
	for card_id: int in stamps:
		stamp_data[str(card_id)] = stamps[card_id]
	var enhancement_data: Dictionary[String, String] = {}
	for card_id: int in enhancements:
		enhancement_data[str(card_id)] = enhancements[card_id]
	return {"stamps": stamp_data, "enhancements": enhancement_data}


## Puts the saved marks back on freshly built deck cards.
func apply(cards: Array[CardInstance]) -> void:
	for card: CardInstance in cards:
		if card.origin() != CardInstance.Origin.DECK:
			continue
		if stamps.has(card.id()):
			CardModifiers.stamp(card, stamps[card.id()])
		if enhancements.has(card.id()):
			CardModifiers.enhance(card, enhancements[card.id()])


## Stamps a deck or plot card as the seat's, for the rest of the run.
static func stamp(state: RunState, card: CardInstance, seat: int) -> void:
	CardModifiers.stamp(card, seat)
	if card.origin() == CardInstance.Origin.DECK:
		state.card_marks.stamps[card.id()] = seat
	for held: CardInstance in _plot_copies(state, card):
		CardModifiers.stamp(held, seat)


## Gives a deck or plot card the enhancement, in place of any it had, for the rest of the
## run.
static func enhance(state: RunState, card: CardInstance, enhancement_id: String) -> void:
	CardModifiers.enhance(card, enhancement_id)
	if card.origin() == CardInstance.Origin.DECK:
		state.card_marks.enhancements[card.id()] = enhancement_id
	for held: CardInstance in _plot_copies(state, card):
		CardModifiers.enhance(held, enhancement_id)


## The plot's own card when the card given is another copy of it, as a view holds, so
## the mark is saved with the plot.
static func _plot_copies(state: RunState, card: CardInstance) -> Array[CardInstance]:
	var copies: Array[CardInstance] = []
	if card.origin() != CardInstance.Origin.PLOT:
		return copies
	for held: CardInstance in state.inventory.plot:
		if held.id() == card.id() and held != card:
			copies.append(held)
	return copies
