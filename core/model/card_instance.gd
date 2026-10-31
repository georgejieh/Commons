class_name CardInstance
extends RefCounted
## One physical card in a run. Enhancement, seal and stamp change only through the
## modifier service (P1C), which is the only caller allowed to use their setters.

enum Origin { DECK, PLOT }

const FIRST_PLOT_ID: int = 1000
const NO_ID: String = ""
const NO_OWNER: int = -1

var id: int
var base_rank: int
var suit: int
var origin: Origin

var _enhancement_id: String = NO_ID
var _seal_id: String = NO_ID
var _owner_stamp: int = NO_OWNER


func _init(card_id: int, rank: int, card_suit: int, card_origin: Origin) -> void:
	id = card_id
	base_rank = rank
	suit = card_suit
	origin = card_origin


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
		"id": id,
		"base_rank": base_rank,
		"suit": suit,
		"origin": origin,
		"enhancement_id": _enhancement_id,
		"seal_id": _seal_id,
		"owner_stamp": _owner_stamp,
	}
