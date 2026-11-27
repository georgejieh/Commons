class_name CardInstance
extends RefCounted
## One physical card in a run. Identity is fixed at construction, because hands cache
## counts by rank. Enhancement, seal and stamp change only through CardModifiers, which
## is the only caller the layer check allows for their setters.

## Where a card came from: DECK for one of the deck's slots, PLOT for a card the run added.
enum Origin { DECK, PLOT }

## The first ID given to a plot card. A deck card's ID is its slot, below this.
const FIRST_PLOT_ID: int = 1000
## The enhancement or seal ID of a card that carries none.
const NO_ID: String = ""
## The owner stamp of a card no seat has stamped.
const NO_OWNER: int = -1
## The first of the enhancements a deck or plot card may carry, one at a time (ADR 0021,
## ADR 0041). Model scores its printed Grain at a percent for whoever scores it.
const MODEL: String = "model"
## An enhancement: a Sheaf adds a flat Grain.
const SHEAF: String = "sheaf"
## An enhancement: a Pennant gives the play that scores it Zeal.
const PENNANT: String = "pennant"
## An enhancement: Surplus pays the household a coupon when the player scores the card.
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


## A card read back from what to_dict wrote; every key must be present.
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
	var card: CardInstance = CardInstance.new(_id, _base_rank, _suit, _origin)
	card._enhancement_id = _enhancement_id
	card._seal_id = _seal_id
	card._owner_stamp = _owner_stamp
	return card


## The number an event gives a mark: 0 for the player's stamp, else the enhancement's
## place in ENHANCEMENTS after one, so Model is 1.
static func mark_value(enhancement: String) -> int:
	return ENHANCEMENTS.find(enhancement) + 1


## The enhancement a mark's number names, or NO_ID for the player's stamp.
static func marked_by(value: int) -> String:
	if value < 1 or value > ENHANCEMENTS.size():
		return NO_ID
	return ENHANCEMENTS[value - 1]


## The card's ID: its slot in the deck, or from FIRST_PLOT_ID up for a plot card.
func id() -> int:
	return _id


## The rank printed on the card, a Ranks index, fixed for the card's life.
func base_rank() -> int:
	return _base_rank


## The card's suit, or Deck.NO_SUIT for a joker. It matters only to scoring.
func suit() -> int:
	return _suit


## Whether the card is one of the deck's slots or a plot card added during the run.
func origin() -> Origin:
	return _origin


## The enhancement the card carries, or NO_ID for none.
func enhancement_id() -> String:
	return _enhancement_id


## The seal the card carries, or NO_ID for none.
func seal_id() -> String:
	return _seal_id


## The seat that has stamped the card, or NO_OWNER for none.
func owner_stamp() -> int:
	return _owner_stamp


## Gives the card an enhancement, or NO_ID to clear it. Only CardModifiers calls it.
func set_enhancement(new_id: String) -> void:
	_enhancement_id = new_id


## Gives the card a seal, or NO_ID to clear it. Only CardModifiers calls it.
func set_seal(new_id: String) -> void:
	_seal_id = new_id


## Stamps the card for a seat, or NO_OWNER to clear it. Only CardModifiers calls it.
func set_owner_stamp(player: int) -> void:
	_owner_stamp = player


## The card as plain data for a save, every field of it; from_dict reads it back.
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
