class_name Ranks
extends RefCounted
## The 15 rank indices. Display labels come from string keys, never from the index.

## The lowest rank, the first of the plain ranks.
const THREE: int = 0
## The rank above Three.
const FOUR: int = 1
## The rank above Four.
const FIVE: int = 2
## The rank above Five.
const SIX: int = 3
## The rank above Six.
const SEVEN: int = 4
## The rank above Seven.
const EIGHT: int = 5
## The rank above Eight.
const NINE: int = 6
## The rank above Nine; bots count anything below it as low.
const TEN: int = 7
## The rank above Ten.
const JACK: int = 8
## The rank above Jack.
const QUEEN: int = 9
## The rank above Queen.
const KING: int = 10
## The rank above King, and the last a chain can reach.
const ACE: int = 11
## The highest plain rank, above Ace; a chain takes it only where the rules say.
const TWO: int = 12
## The rank above Two; with the big joker it makes the rocket.
const SMALL_JOKER: int = 13
## The highest rank of all, above the small joker.
const BIG_JOKER: int = 14

## The number of ranks, the plain ones and the two jokers; the length of a count vector.
const COUNT: int = 15
## The highest rank a chain may end on by default, which is Ace.
const LAST_CHAINABLE: int = ACE
## Stands for no rank.
const INVALID: int = -1

## The string table key of each rank's label, by rank index.
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


## True when the index names one of the ranks.
static func is_valid(rank: int) -> bool:
	return rank >= 0 and rank < COUNT


## Returns the string table key for a valid rank.
static func label_key(rank: int) -> String:
	return LABEL_KEYS[rank]


## Returns the map where every rank is its own effective rank.
static func identity_map() -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	result.resize(COUNT)
	for rank: int in COUNT:
		result[rank] = rank
	return result
