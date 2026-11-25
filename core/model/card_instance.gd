class_name CardInstance
extends RefCounted
## One physical card in a run. Identity is fixed at construction, because hands cache
## counts by rank. Enhancement, seal and stamp change only through CardModifiers, which
## is the only caller the layer check allows for their setters.

enum Origin { DECK, PLOT }

const FIRST_PLOT_ID: int = 1000
const NO_ID: String = ""
const NO_OWNER: int = -1
## The enhancements a deck or plot card may carry, one at a time (ADR 0021, ADR 0041).
## Model scores its printed Grain at a percent for whoever scores it; a Sheaf adds a flat
## Grain; Pennant gives the play that scores it Zeal; Surplus pays the household a coupon
## when the player scores it.
const MODEL: String = "model"
const SHEAF: String = "sheaf"
const PENNANT: String = "pennant"
const SURPLUS: String = "surplus"
## Every enhancement, in the order the game lists them.
const ENHANCEMENTS: Array[String] = [MODEL, SHEAF, PENNANT, SURPLUS]

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


## The number an event gives a mark: 0 for the player's stamp, else the enhancement's
## place in ENHANCEMENTS after one, so Model is 1.
static func mark_value(enhancement_id: String) -> int:
	return ENHANCEMENTS.find(enhancement_id) + 1


## The enhancement a mark's number names, or NO_ID for the player's stamp.
static func marked_by(value: int) -> String:
	if value < 1 or value > ENHANCEMENTS.size():
		return NO_ID
	return ENHANCEMENTS[value - 1]


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
