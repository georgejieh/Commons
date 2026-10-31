class_name Pattern
extends RefCounted
## One legal play as ranks, with its comparison key fixed at construction.
## Ranks are base ranks. Only the key uses the effective rank.

enum Type {
	PASS,
	SINGLE,
	PAIR,
	TRIO,
	TRIO_SINGLE,
	TRIO_PAIR,
	STRAIGHT,
	PAIR_CHAIN,
	AIRPLANE,
	AIRPLANE_SINGLES,
	AIRPLANE_PAIRS,
	FOUR_TWO_SINGLES,
	FOUR_TWO_PAIRS,
	BOMB,
	ROCKET,
}

const KEY_RANK_BITS: int = 8
const KEY_CHAIN_SHIFT: int = 8
const KEY_COUNT_SHIFT: int = 16
const KEY_TYPE_SHIFT: int = 24
const IDENTITY_TYPE_SHIFT: int = 60

var type: Type
var main_rank: int
var chain_length: int
var card_count: int
## Sorted low to high.
var kicker_ranks: PackedByteArray
## Orders plays of one shape by main rank. Shape is everything above KEY_RANK_BITS.
var key: int


func _init(
	pattern_type: Type,
	main: int,
	chain: int,
	cards: int,
	kickers: PackedByteArray,
	effective_main: int
) -> void:
	type = pattern_type
	main_rank = main
	chain_length = chain
	card_count = cards
	kicker_ranks = kickers
	key = (
		(type << KEY_TYPE_SHIFT)
		| (card_count << KEY_COUNT_SHIFT)
		| (chain_length << KEY_CHAIN_SHIFT)
		| effective_main
	)


static func pass_play() -> Pattern:
	return Pattern.new(Type.PASS, Ranks.INVALID, 0, 0, PackedByteArray(), 0)


func shape() -> int:
	return key >> KEY_RANK_BITS


## Cards per rank in the body.
func body_width() -> int:
	if chain_length == 0:
		return 0
	@warning_ignore("integer_division")
	return (card_count - kicker_ranks.size()) / chain_length


## Returns the rank counts this play uses.
func counts() -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	result.resize(Ranks.COUNT)
	if type == Type.ROCKET:
		result[Ranks.SMALL_JOKER] = 1
		result[Ranks.BIG_JOKER] = 1
		return result
	var width: int = body_width()
	for offset: int in chain_length:
		result[main_rank + offset] = width
	for rank: int in kicker_ranks:
		result[rank] += 1
	return result


## Equal only for the same type and the same cards.
func identity() -> int:
	return CountKey.encode(counts()) | (type << IDENTITY_TYPE_SHIFT)


func equals(other: Pattern) -> bool:
	return key == other.key and identity() == other.identity()
