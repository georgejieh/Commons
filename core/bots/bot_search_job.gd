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
		_results.append(PackedInt32Array())


## False when there is no choice to make or the unseen cards can't be dealt.
func is_ready() -> bool:
	return not _hands.is_empty()


func sample_count() -> int:
	return _hands.size()


func run_sample(sample: int) -> void:
	var hands: Array[PackedByteArray] = []
	hands.assign(_hands[sample])
	var row: PackedInt32Array = PackedInt32Array()
	row.resize(_candidates.size())
	for index: int in _candidates.size():
		row[index] = ExpertSearch.roll(_position, hands, _candidates[index])
	_results[sample] = row


## Decides on the samples finished so far. The policy's play stands unless a rival beats
## it by the margin, and stands outright if too few samples finished.
func best() -> BotPlay:
	var wins: PackedInt32Array = PackedInt32Array()
	wins.resize(_candidates.size())
	for row: PackedInt32Array in _results:
		for index: int in row.size():
			wins[index] += row[index]
	var weights: BotWeights = _position.config.weights
	var finished: int = finished_samples()
	if finished == 0 or finished < weights.expert_min_samples:
		return fallback
	var top: int = 0
	for index: int in wins.size():
		if wins[index] > wins[top]:
			top = index
	if not clears_margin(wins[top] - wins[0], finished, weights.expert_margin):
		return fallback
	return BotPlay.new(_candidates[top], BotRationale.Code.SEARCHED)


func finished_samples() -> int:
	var finished: int = 0
	for row: PackedInt32Array in _results:
		if not row.is_empty():
			finished += 1
	return finished


## True if a rival's lead over the policy's play, in wins, is enough to overturn it.
static func clears_margin(lead: int, finished: int, margin: float) -> bool:
	return lead > 0 and lead >= ceili(finished * margin)
