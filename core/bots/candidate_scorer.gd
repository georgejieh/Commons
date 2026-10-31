class_name CandidateScorer
extends RefCounted
## Scores a candidate by the hand it leaves: the sum of group values less a cost for each
## round still needed (sm9sun's baseline). Passing keeps the hand and costs one more round.
## One instance serves one decision, so every candidate shares the search's memo.

var _counts: PackedByteArray
var _weights: BotWeights
var _decomposer: HandDecomposer


func _init(counts: PackedByteArray, table: BotTable, weights: BotWeights) -> void:
	_counts = counts
	_weights = weights
	_decomposer = HandDecomposer.new(table.rules, table.rank_map, weights.memo_cap)


func score_play(move: Pattern) -> float:
	var left: PackedByteArray = _counts.duplicate()
	var used: PackedByteArray = move.counts()
	var cards_left: int = 0
	for rank: int in Ranks.COUNT:
		left[rank] -= used[rank]
		cards_left += left[rank]
	if cards_left == 0:
		return _weights.win_value
	return _hand_value(left, 0)


func score_pass() -> float:
	return _hand_value(_counts, 1)


func decompose_own_hand() -> Decomposition:
	return _decomposer.decompose(_counts)


func _hand_value(counts: PackedByteArray, extra_rounds: int) -> float:
	var groups: Array[Pattern] = _decomposer.decompose(counts).groups
	var value: float = 0.0
	for group: Pattern in groups:
		value += _group_value(group)
	return value - _weights.round_penalty * (groups.size() + extra_rounds)


func _group_value(group: Pattern) -> float:
	var top: int = group.main_rank + group.chain_length - 1
	return top - _weights.rank_offset + _weights.type_bonus[group.type]
