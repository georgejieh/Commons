class_name BotSearchJob
extends RefCounted
## One search, split into samples. Each sample writes only its own row, so a runner may
## give samples to different threads. Everything here is pure.

## What the policy would play. It stands if the search can't finish.
var fallback: BotPlay

var _position: BotPosition
var _candidates: Array[Pattern]
var _hands: Array[Array] = []
var _results: Array[PackedInt32Array] = []


func _init(position: BotPosition, legal: Array[Pattern], policy_play: BotPlay) -> void:
	_position = position
	fallback = policy_play
	if legal.is_empty():
		return
	_candidates = ExpertSearch.top_candidates(position, legal, policy_play)
	if _candidates.size() < 2:
		return
	for sample: int in position.config.search_samples():
		var hands: Array[PackedByteArray] = ExpertSearch.deal_unseen(position, sample)
		if hands.is_empty():
			_hands.clear()
			return
		_hands.append(hands)
		var row: PackedInt32Array = PackedInt32Array()
		row.resize(_candidates.size())
		_results.append(row)


## False when there is no choice to make or the unseen cards can't be dealt.
func is_ready() -> bool:
	return not _hands.is_empty()


func sample_count() -> int:
	return _hands.size()


func run_sample(sample: int) -> void:
	var hands: Array[PackedByteArray] = []
	hands.assign(_hands[sample])
	var row: PackedInt32Array = _results[sample]
	for index: int in _candidates.size():
		row[index] = ExpertSearch.roll(_position, hands, _candidates[index])
	_results[sample] = row


func best() -> BotPlay:
	var wins: PackedInt32Array = PackedInt32Array()
	wins.resize(_candidates.size())
	for row: PackedInt32Array in _results:
		for index: int in row.size():
			wins[index] += row[index]
	var top: int = 0
	for index: int in wins.size():
		if wins[index] > wins[top]:
			top = index
	return BotPlay.new(_candidates[top], BotRationale.Code.SEARCHED)
