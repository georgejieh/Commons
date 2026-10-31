class_name Ranks
extends RefCounted
## The 15 rank indices. Display labels come from string keys, never from the index.

const THREE: int = 0
const FOUR: int = 1
const FIVE: int = 2
const SIX: int = 3
const SEVEN: int = 4
const EIGHT: int = 5
const NINE: int = 6
const TEN: int = 7
const JACK: int = 8
const QUEEN: int = 9
const KING: int = 10
const ACE: int = 11
const TWO: int = 12
const SMALL_JOKER: int = 13
const BIG_JOKER: int = 14

const COUNT: int = 15
const LAST_CHAINABLE: int = ACE
const INVALID: int = -1

const LABEL_KEYS: PackedStringArray = [
	"rank.3",
	"rank.4",
	"rank.5",
	"rank.6",
	"rank.7",
	"rank.8",
	"rank.9",
	"rank.10",
	"rank.j",
	"rank.q",
	"rank.k",
	"rank.a",
	"rank.2",
	"rank.small_joker",
	"rank.big_joker",
]


static func is_valid(rank: int) -> bool:
	return rank >= 0 and rank < COUNT


static func is_chainable(rank: int) -> bool:
	return rank >= 0 and rank <= LAST_CHAINABLE


## Returns the string table key for a valid rank.
static func label_key(rank: int) -> String:
	return LABEL_KEYS[rank]


## Returns the rank for a label key, or INVALID.
static func from_label_key(key: String) -> int:
	return LABEL_KEYS.find(key)
