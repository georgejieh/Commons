class_name Pattern
extends RefCounted
## One legal play as ranks, with its comparison key fixed at construction.
## Ranks are base ranks. Only the key uses the effective rank. A play is a reading of the
## cards it spends (ADR 0029): the type and ranks below are the reading, every card as
## what it stands for, and spent holds the printed ranks only when a wild card stands in.

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
## The printed rank counts of the cards spent, or empty when they are the reading's own
## counts, as they always are with no wild card standing in.
var spent: PackedByteArray = PackedByteArray()
## True when the seat that read the play holds its main rank wild. Wild ranks can be one
## seat's alone (ADR 0039), so four of them read as that rank are the pure-wild bomb by
## the rules of the seat that played them, whoever compares the play.
var main_wild: bool = false


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


## Returns an independent copy, so a view can never reach the round's own play.
func copy() -> Pattern:
	return rekeyed(key & ((1 << KEY_RANK_BITS) - 1))


## Returns a copy compared at a new effective rank.
func rekeyed(effective_main: int) -> Pattern:
	var kickers: PackedByteArray = kicker_ranks.duplicate()
	var result: Pattern = Pattern.new(
		type, main_rank, chain_length, card_count, kickers, effective_main
	)
	result.spent = spent.duplicate()
	result.main_wild = main_wild
	return result


func shape() -> int:
	return key >> KEY_RANK_BITS


## Cards per rank in the body.
func body_width() -> int:
	if chain_length == 0:
		return 0
	@warning_ignore("integer_division")
	return (card_count - kicker_ranks.size()) / chain_length


## Returns the rank counts of the reading: every card as the rank it stands for.
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


## Returns the printed rank counts of the cards the play spends, which leave the hand.
func spent_counts() -> PackedByteArray:
	return counts() if spent.is_empty() else spent.duplicate()


## Cards standing in for a rank other than their own: the fewest the cards allow.
func stand_ins() -> int:
	if spent.is_empty():
		return 0
	var reading: PackedByteArray = counts()
	var total: int = 0
	for rank: int in Ranks.COUNT:
		total += maxi(0, reading[rank] - spent[rank])
	return total


## Equal only for the same type and the same reading.
func identity() -> int:
	return CountKey.encode(counts()) | (type << IDENTITY_TYPE_SHIFT)


## The same reading, whatever cards spend it and whichever scale its key was read on: a
## seat's order or its standings (ADR 0039).
func same_reading(other: Pattern) -> bool:
	return (
		shape() == other.shape() and main_rank == other.main_rank and identity() == other.identity()
	)


## The same reading of the same cards.
func equals(other: Pattern) -> bool:
	return same_reading(other) and spent == other.spent


## Notes whether the rules of the seat reading the play hold its main rank wild.
func read_under(rules: RuleSet) -> Pattern:
	main_wild = rules.is_wild(main_rank)
	return self


## Records the printed counts the play spends, kept only when they differ from the
## reading's, so a play with no stand-in compares as it always has.
func spend(printed: PackedByteArray) -> void:
	spent = PackedByteArray() if printed == counts() else printed.duplicate()
