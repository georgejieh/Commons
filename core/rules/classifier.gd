class_name Classifier
extends RefCounted
## Reads one play from a count vector. Works from the masks of ranks holding 1, 2, 3
## and 4 cards, so a call is O(15) with no subset search. See ADR 0007.

const SINGLE_BODY: int = 1
const PAIR_BODY: int = 2
const TRIO_BODY: int = 3
const QUAD_BODY: int = 4
const ROCKET_MASK: int = (1 << Ranks.SMALL_JOKER) | (1 << Ranks.BIG_JOKER)
const TWO_AND_UP_MASK: int = (1 << Ranks.TWO) | ROCKET_MASK
const NO_KICKERS: PackedByteArray = []

## Index is a rank's card count. Counts above four land in the last slot.
var _masks: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
var _rules: RuleSet
var _rank_map: PackedByteArray


func _init(rules: RuleSet, rank_map: PackedByteArray) -> void:
	_rules = rules
	_rank_map = rank_map


static func classify(
	counts: PackedByteArray, rules: RuleSet, rank_map: PackedByteArray
) -> Classification:
	return Classifier.new(rules, rank_map)._read(counts)


func _read(counts: PackedByteArray) -> Classification:
	var total: int = 0
	var present: int = 0
	var top_count: int = 0
	var top_rank: int = Ranks.INVALID
	for rank: int in Ranks.COUNT:
		var count: int = counts[rank]
		if count == 0:
			continue
		total += count
		present += 1
		top_count = maxi(top_count, count)
		top_rank = rank
		_masks[mini(count, QUAD_BODY + 1)] |= 1 << rank

	if total == 0:
		return Classification.new(null, Classification.Reason.EMPTY)
	if present == 1:
		return _one_rank(top_rank, total)
	if _masks[SINGLE_BODY] == ROCKET_MASK and present == 2:
		return _valid(Pattern.Type.ROCKET, Ranks.SMALL_JOKER, 1, total)
	return _several_ranks(top_count, total)


func _several_ranks(top_count: int, total: int) -> Classification:
	if top_count > QUAD_BODY:
		return _invalid(Classification.Reason.UNKNOWN_SHAPE)
	if top_count == QUAD_BODY:
		return _four_with_two(total)
	if top_count == TRIO_BODY:
		return _trios(total)
	if _masks[SINGLE_BODY] != 0 and _masks[PAIR_BODY] != 0:
		return _invalid(Classification.Reason.UNKNOWN_SHAPE)
	if top_count == PAIR_BODY:
		return _chain(
			_masks[PAIR_BODY], PAIR_BODY, _rules.min_pair_chain_length(), Pattern.Type.PAIR_CHAIN
		)
	return _chain(
		_masks[SINGLE_BODY], SINGLE_BODY, _rules.min_straight_length(), Pattern.Type.STRAIGHT
	)


func _one_rank(rank: int, total: int) -> Classification:
	match total:
		SINGLE_BODY:
			return _valid(Pattern.Type.SINGLE, rank, 1, total)
		PAIR_BODY:
			return _valid(Pattern.Type.PAIR, rank, 1, total)
		TRIO_BODY:
			return _valid(Pattern.Type.TRIO, rank, 1, total)
		QUAD_BODY:
			return _valid(Pattern.Type.BOMB, rank, 1, total)
	if _rules.five_plus_is_bomb():
		return _valid(Pattern.Type.BOMB, rank, 1, total)
	return _invalid(Classification.Reason.UNKNOWN_SHAPE)


func _chain(mask: int, width: int, minimum: int, type: Pattern.Type) -> Classification:
	var length: int = _bit_count(mask)
	var failure: Classification = _chain_failure(mask, length, minimum)
	if failure != null:
		return failure
	return _valid(type, _lowest_rank(mask), length, length * width)


## Returns why a mask is not a legal chain, or null if it is one.
func _chain_failure(mask: int, length: int, minimum: int) -> Classification:
	if mask >= 1 << (_rules.last_chain_rank() + 1):
		return _invalid(Classification.Reason.UNCHAINABLE_RANK)
	if not _is_consecutive(mask, length):
		return _invalid(Classification.Reason.UNKNOWN_SHAPE)
	if length < minimum:
		return _invalid(Classification.Reason.CHAIN_TOO_SHORT)
	return null


func _trios(total: int) -> Classification:
	var trios: int = _masks[TRIO_BODY]
	var singles: int = _masks[SINGLE_BODY]
	var pairs: int = _masks[PAIR_BODY]
	var length: int = _bit_count(trios)
	if length > 1:
		return _airplane(trios, length, total)
	var main: int = _lowest_rank(trios)
	if _bit_count(pairs) == 1 and singles == 0:
		return _valid(Pattern.Type.TRIO_PAIR, main, 1, total, _ranks_of(pairs, PAIR_BODY))
	if _bit_count(singles) == 1 and pairs == 0:
		return _valid(Pattern.Type.TRIO_SINGLE, main, 1, total, _ranks_of(singles, SINGLE_BODY))
	return _invalid(Classification.Reason.BAD_KICKERS)


func _airplane(trios: int, length: int, total: int) -> Classification:
	var failure: Classification = _chain_failure(trios, length, _rules.min_airplane_length())
	if failure != null:
		return failure
	var main: int = _lowest_rank(trios)
	var singles: int = _masks[SINGLE_BODY]
	var pairs: int = _masks[PAIR_BODY]
	if singles == 0 and pairs == 0:
		return _valid(Pattern.Type.AIRPLANE, main, length, total)
	return _wings(main, length, total)


func _wings(main: int, length: int, total: int) -> Classification:
	var singles: int = _masks[SINGLE_BODY]
	var pairs: int = _masks[PAIR_BODY]
	if not _rules.joker_or_two_may_be_wing() and (singles | pairs) & TWO_AND_UP_MASK != 0:
		return _invalid(Classification.Reason.BAD_WINGS)
	if not _rules.rocket_may_be_kicker() and singles & ROCKET_MASK == ROCKET_MASK:
		return _invalid(Classification.Reason.ROCKET_AS_KICKER)

	var single_ranks: int = _bit_count(singles)
	var pair_ranks: int = _bit_count(pairs)
	if pairs == 0 and single_ranks == length and _rules.single_wings_allowed():
		var kickers: PackedByteArray = _ranks_of(singles, SINGLE_BODY)
		return _valid(Pattern.Type.AIRPLANE_SINGLES, main, length, total, kickers)
	if singles == 0 and pair_ranks == length and _rules.pair_wings_allowed():
		var kickers: PackedByteArray = _ranks_of(pairs, PAIR_BODY)
		return _valid(Pattern.Type.AIRPLANE_PAIRS, main, length, total, kickers)
	var paired_singles: bool = singles == 0 and pair_ranks * PAIR_BODY == length
	if paired_singles and _rules.single_wings_allowed() and _rules.single_wings_may_pair():
		var kickers: PackedByteArray = _ranks_of(pairs, PAIR_BODY)
		return _valid(Pattern.Type.AIRPLANE_SINGLES, main, length, total, kickers)
	return _invalid(Classification.Reason.BAD_WINGS)


func _four_with_two(total: int) -> Classification:
	var quads: int = _masks[QUAD_BODY]
	var singles: int = _masks[SINGLE_BODY]
	var pairs: int = _masks[PAIR_BODY]
	if _bit_count(quads) != 1 or _masks[TRIO_BODY] != 0:
		return _invalid(Classification.Reason.BAD_KICKERS)
	var main: int = _lowest_rank(quads)
	if not _rules.rocket_may_be_kicker() and singles == ROCKET_MASK:
		return _invalid(Classification.Reason.ROCKET_AS_KICKER)
	if _rules.four_two_singles_allowed():
		var kickers: PackedByteArray = _four_two_single_kickers(singles, pairs)
		if not kickers.is_empty():
			return _valid(Pattern.Type.FOUR_TWO_SINGLES, main, 1, total, kickers)
	if singles == 0 and _bit_count(pairs) == 2 and _rules.four_two_pairs_allowed():
		var kickers: PackedByteArray = _ranks_of(pairs, PAIR_BODY)
		return _valid(Pattern.Type.FOUR_TWO_PAIRS, main, 1, total, kickers)
	return _invalid(Classification.Reason.BAD_KICKERS)


## Returns the two single kickers, or nothing if the cards don't form them.
func _four_two_single_kickers(singles: int, pairs: int) -> PackedByteArray:
	if pairs == 0 and _bit_count(singles) == 2:
		return _ranks_of(singles, SINGLE_BODY)
	var shared: bool = singles == 0 and _bit_count(pairs) == 1
	if shared and _rules.four_two_singles_may_share_rank():
		return _ranks_of(pairs, PAIR_BODY)
	return PackedByteArray()


func _valid(
	type: Pattern.Type, main: int, chain: int, total: int, kickers: PackedByteArray = NO_KICKERS
) -> Classification:
	var pattern: Pattern = Pattern.new(type, main, chain, total, kickers, _rank_map[main])
	return Classification.new(pattern, Classification.Reason.OK)


func _invalid(reason: Classification.Reason) -> Classification:
	return Classification.new(null, reason)


func _is_consecutive(mask: int, length: int) -> bool:
	return mask == ((1 << length) - 1) << _lowest_rank(mask)


func _lowest_rank(mask: int) -> int:
	for rank: int in Ranks.COUNT:
		if mask & (1 << rank) != 0:
			return rank
	return Ranks.INVALID


func _bit_count(mask: int) -> int:
	var total: int = 0
	var rest: int = mask
	while rest != 0:
		rest &= rest - 1
		total += 1
	return total


## Returns each rank in the mask, repeated, low to high.
func _ranks_of(mask: int, copies: int) -> PackedByteArray:
	var ranks: PackedByteArray = PackedByteArray()
	for rank: int in Ranks.COUNT:
		if mask & (1 << rank) != 0:
			for _copy: int in copies:
				ranks.append(rank)
	return ranks
