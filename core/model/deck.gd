class_name Deck
extends RefCounted
## The 54-card base deck. Suit exists only for scoring and never affects legality.

const SIZE: int = 54
const SUITS: int = 4
const SMALL_JOKER_ID: int = 52
const BIG_JOKER_ID: int = 53
const NO_SUIT: int = -1


## Returns every base card ID in order.
static func generate() -> PackedInt32Array:
	var ids: PackedInt32Array = []
	ids.resize(SIZE)
	for id: int in SIZE:
		ids[id] = id
	return ids


static func rank_of(id: int) -> int:
	if id == SMALL_JOKER_ID:
		return Ranks.SMALL_JOKER
	if id == BIG_JOKER_ID:
		return Ranks.BIG_JOKER
	@warning_ignore("integer_division")
	return id / SUITS


static func suit_of(id: int) -> int:
	if id >= SMALL_JOKER_ID:
		return NO_SUIT
	return id % SUITS
