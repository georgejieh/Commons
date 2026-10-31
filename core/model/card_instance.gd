class_name CardInstance
extends RefCounted
## One physical card in a run. Identity is fixed at construction, because hands cache
## counts by rank. Enhancement, seal and stamp change only through CardModifiers, which
## is the only caller the layer check allows for their setters.

enum Origin { DECK, PLOT }

const FIRST_PLOT_ID: int = 1000
const NO_ID: String = ""
const NO_OWNER: int = -1

var _id: int
var _base_rank: int
var _suit: int
var _origin: Origin
var _enhancement_id: String = NO_ID
var _seal_id: String = NO_ID
var _owner_stamp: int = NO_OWNER


func _init(card_id: int, rank: int, card_suit: int, card_origin: Origin) -> void:
	_id = card_id
	_base_rank = rank
	_suit = card_suit
	_origin = card_origin


static func from_deck_id(deck_id: int) -> CardInstance:
	return CardInstance.new(deck_id, Deck.rank_of(deck_id), Deck.suit_of(deck_id), Origin.DECK)


static func from_dict(data: Dictionary) -> CardInstance:
	var origin_value: Origin = int(data["origin"]) as Origin
	var card: CardInstance = CardInstance.new(
		int(data["id"]), int(data["base_rank"]), int(data["suit"]), origin_value
	)
	card._enhancement_id = str(data["enhancement_id"])
	card._seal_id = str(data["seal_id"])
	card._owner_stamp = int(data["owner_stamp"])
	return card


## Returns an independent copy, for views of a hand.
func snapshot() -> CardInstance:
	return CardInstance.from_dict(to_dict())


func id() -> int:
	return _id


func base_rank() -> int:
	return _base_rank


func suit() -> int:
	return _suit


func origin() -> Origin:
	return _origin


func enhancement_id() -> String:
	return _enhancement_id


func seal_id() -> String:
	return _seal_id


func owner_stamp() -> int:
	return _owner_stamp


func set_enhancement(new_id: String) -> void:
	_enhancement_id = new_id


func set_seal(new_id: String) -> void:
	_seal_id = new_id


func set_owner_stamp(player: int) -> void:
	_owner_stamp = player


func to_dict() -> Dictionary:
	return {
		"id": _id,
		"base_rank": _base_rank,
		"suit": _suit,
		"origin": _origin,
		"enhancement_id": _enhancement_id,
		"seal_id": _seal_id,
		"owner_stamp": _owner_stamp,
	}
