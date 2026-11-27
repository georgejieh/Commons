class_name Deck
extends RefCounted
## A 54-card deck by slot: the rank and suit of the card in each of the 54 slot IDs. A new
## Deck is the plain deck, four of each rank from 3 to 2 in the four suits and the two
## jokers; it is the only place a slot's card follows from its ID. The run's communal deck
## is one Deck, changed only by an exchange at the state store, which puts another card in
## a slot for the rest of the run (ADR 0042). Suit exists only for scoring and never
## affects legality. The jokers stay in their own slots, since no exchange takes one out.
## Marks are not part of a slot: CardMarks keeps them by slot ID.

## The number of slots, so every deck card's ID is below it.
const SIZE: int = 54
## The number of suits a card of a plain rank can have.
const SUITS: int = 4
## The slot of the small joker, which no exchange takes out.
const SMALL_JOKER_ID: int = 52
## The slot of the big joker, which no exchange takes out.
const BIG_JOKER_ID: int = 53
## The suit of a joker, which has none.
const NO_SUIT: int = -1
## A slot named by nothing, as an envelope pick that takes no deck card out.
const NO_SLOT: int = -1
## Where a saved slot's pair keeps its rank.
const RANK_AT: int = 0
## Where a saved slot's pair keeps its suit.
const SUIT_AT: int = 1

var _ranks: PackedByteArray = PackedByteArray()
var _suits: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	_ranks.resize(SIZE)
	_suits.resize(SIZE)
	for slot: int in SMALL_JOKER_ID:
		@warning_ignore("integer_division")
		_ranks[slot] = slot / SUITS
		_suits[slot] = slot % SUITS
	_ranks[SMALL_JOKER_ID] = Ranks.SMALL_JOKER
	_ranks[BIG_JOKER_ID] = Ranks.BIG_JOKER
	_suits[SMALL_JOKER_ID] = NO_SUIT
	_suits[BIG_JOKER_ID] = NO_SUIT


## A deck with the saved slots in place of the plain deck's cards. JSON keys are text, so
## slot IDs come back from it as strings.
static func from_dict(data: Dictionary) -> Deck:
	var deck: Deck = Deck.new()
	for key: Variant in data:
		var pair: Array = data[key]
		deck.replace(str(key).to_int(), int(pair[RANK_AT]), int(pair[SUIT_AT]))
	return deck


## True when data has the saved shape: slot IDs below the jokers', each to a rank from 3
## to 2 and a suit.
static func is_valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var data: Dictionary = value
	for key: Variant in data:
		var slot: int = str(key).to_int()
		if not str(key).is_valid_int() or slot < 0 or slot >= SMALL_JOKER_ID:
			return false
		if not data[key] is Array:
			return false
		var pair: Array = data[key]
		if pair.size() != 2:
			return false
		for part: Variant in pair:
			if not (part is int or part is float):
				return false
		if not Ranks.is_valid(int(pair[RANK_AT])) or int(pair[RANK_AT]) > Ranks.TWO:
			return false
		if int(pair[SUIT_AT]) < 0 or int(pair[SUIT_AT]) >= SUITS:
			return false
	return true


## The slots whose card is not the plain deck's, each to its rank and suit, so a deck
## nobody changed saves as nothing.
func to_dict() -> Dictionary:
	var changed: Dictionary[String, Array] = {}
	for slot: int in changed_slots():
		changed[str(slot)] = [_ranks[slot], _suits[slot]]
	return changed


## A deck of its own with the same card in every slot, so changing one leaves the other.
func copy() -> Deck:
	var deck: Deck = Deck.new()
	deck._ranks = _ranks.duplicate()
	deck._suits = _suits.duplicate()
	return deck


## The rank of the card in the slot, a Ranks index.
func rank_of(slot: int) -> int:
	return _ranks[slot]


## The suit of the card in the slot, or NO_SUIT for a joker.
func suit_of(slot: int) -> int:
	return _suits[slot]


## A fresh, unmarked card for the slot, as a deal builds it.
func card(slot: int) -> CardInstance:
	return CardInstance.new(slot, _ranks[slot], _suits[slot], CardInstance.Origin.DECK)


## A fresh, unmarked card for every slot, in slot order.
func cards() -> Array[CardInstance]:
	var all: Array[CardInstance] = []
	for slot: int in SIZE:
		all.append(card(slot))
	return all


## How many cards of each rank the deck holds.
func rank_counts() -> PackedByteArray:
	var counts: PackedByteArray = PackedByteArray()
	counts.resize(Ranks.COUNT)
	for slot: int in SIZE:
		counts[_ranks[slot]] += 1
	return counts


## Puts the card of rank and suit in the slot, in place of the one there.
func replace(slot: int, rank: int, suit: int) -> void:
	_ranks[slot] = rank
	_suits[slot] = suit


## The slots whose card is not the plain deck's, in slot order.
func changed_slots() -> Array[int]:
	var plain: Deck = Deck.new()
	var slots: Array[int] = []
	for slot: int in SIZE:
		if _ranks[slot] != plain._ranks[slot] or _suits[slot] != plain._suits[slot]:
			slots.append(slot)
	return slots
