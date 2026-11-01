class_name DecompositionLeaf
extends RefCounted
## Counts the plays for what is left outside chains, in closed form: bombs + rocket +
## trios + max(0, singles + pairs - trios), with trios and airplanes absorbing kickers.

enum Wing { NONE, SINGLES, PAIRS, PAIRS_IN_SINGLE_SLOTS }

const LOW_LIMIT_RANK: int = Ranks.TEN

## The score of the last read, lower is better.
var score: int = 0

var _rules: RuleSet
var _rank_map: PackedByteArray
var _singles: PackedByteArray = PackedByteArray()
var _pairs: PackedByteArray = PackedByteArray()
var _trios: PackedByteArray = PackedByteArray()
var _bombs: PackedByteArray = PackedByteArray()
var _has_rocket: bool = false
var _planes: PackedInt32Array = PackedInt32Array()
var _best_wings: PackedByteArray = PackedByteArray()
var _best_absorbed: int = -1
var _best_low: int = -1
var _wings: PackedByteArray = PackedByteArray()


func _init(rules: RuleSet, rank_map: PackedByteArray) -> void:
	_rules = rules
	_rank_map = rank_map


func read(counts: PackedByteArray, planes: PackedInt32Array) -> DecompositionLeaf:
	_sort_ranks(counts)
	_planes = planes
	_plan_wings()
	var strength: int = _whole_group_strength()
	var groups_left: int = _bombs.size() + _trios.size() + (1 if _has_rocket else 0)
	var loose: PackedByteArray = _loose_singles()
	var spare_pairs: PackedByteArray = _loose_pairs()
	var free_singles: int = mini(_trios.size(), loose.size())
	var free_pairs: int = mini(_trios.size() - free_singles, spare_pairs.size())
	var low_left: int = 0
	for index: int in range(free_singles, loose.size()):
		groups_left += 1
		strength += _rank_map[loose[index]]
		if _rank_map[loose[index]] < _rank_map[LOW_LIMIT_RANK]:
			low_left += 1
	for index: int in range(free_pairs, spare_pairs.size()):
		groups_left += 1
		strength += _rank_map[spare_pairs[index]]
	score = (
		(groups_left << HandDecomposer.HAND_SHIFT)
		+ (low_left << HandDecomposer.LOW_SINGLE_SHIFT)
		- strength
	)
	return self


## Returns the plays this leaf counted, including its airplanes.
func groups(counts: PackedByteArray, planes: PackedInt32Array) -> Array[Pattern]:
	read(counts, planes)
	var result: Array[Pattern] = []
	var loose: PackedByteArray = _loose_singles()
	var spare_pairs: PackedByteArray = _loose_pairs()
	for index: int in _planes.size():
		result.append(_plane_group(index))
	for trio: int in _trios:
		if not loose.is_empty():
			result.append(_trio(trio, Pattern.Type.TRIO_SINGLE, loose[0], 1))
			loose.remove_at(0)
		elif not spare_pairs.is_empty():
			result.append(_trio(trio, Pattern.Type.TRIO_PAIR, spare_pairs[0], 2))
			spare_pairs.remove_at(0)
		else:
			result.append(_group(Pattern.Type.TRIO, trio, 1, HandDecomposer.TRIO_WIDTH))
	for rank: int in loose:
		result.append(_group(Pattern.Type.SINGLE, rank, 1, 1))
	for rank: int in spare_pairs:
		result.append(_group(Pattern.Type.PAIR, rank, 1, HandDecomposer.PAIR_WIDTH))
	for rank: int in _bombs:
		var width: int = HandDecomposer.BOMB_WIDTH
		if _rules.five_plus_is_bomb():
			width = counts[rank]
		result.append(_group(Pattern.Type.BOMB, rank, 1, width))
	if _has_rocket:
		var cards: int = HandDecomposer.PAIR_WIDTH
		result.append(_group(Pattern.Type.ROCKET, Ranks.SMALL_JOKER, 1, cards))
	return result


func _whole_group_strength() -> int:
	var strength: int = 0
	for rank: int in _bombs:
		strength += _rank_map[rank]
	for rank: int in _trios:
		strength += _rank_map[rank]
	if _has_rocket:
		strength += _rank_map[Ranks.BIG_JOKER]
	return strength


func _sort_ranks(counts: PackedByteArray) -> void:
	_singles.clear()
	_pairs.clear()
	_trios.clear()
	_bombs.clear()
	_has_rocket = counts[Ranks.SMALL_JOKER] > 0 and counts[Ranks.BIG_JOKER] > 0
	for rank: int in Ranks.COUNT:
		var count: int = counts[rank]
		if _has_rocket and rank >= Ranks.SMALL_JOKER:
			count -= 1
		if count >= HandDecomposer.BOMB_WIDTH and _rules.five_plus_is_bomb():
			_bombs.append(rank)
			continue
		while count >= HandDecomposer.BOMB_WIDTH:
			_bombs.append(rank)
			count -= HandDecomposer.BOMB_WIDTH
		match count:
			HandDecomposer.SINGLE_WIDTH:
				_singles.append(rank)
			HandDecomposer.PAIR_WIDTH:
				_pairs.append(rank)
			HandDecomposer.TRIO_WIDTH:
				_trios.append(rank)


## Tries every wing kind per airplane. Few airplanes fit in a hand, so this stays small.
func _plan_wings() -> void:
	_best_absorbed = -1
	_best_low = -1
	_wings.resize(_planes.size())
	_best_wings = PackedByteArray()
	_best_wings.resize(_planes.size())
	if not _planes.is_empty():
		_try_wings(0, _singles.duplicate(), _pairs.duplicate(), 0, 0)


func _try_wings(
	index: int, singles: PackedByteArray, pairs: PackedByteArray, absorbed: int, low: int
) -> void:
	if index == _planes.size():
		if absorbed > _best_absorbed or (absorbed == _best_absorbed and low > _best_low):
			_best_absorbed = absorbed
			_best_low = low
			_best_wings = _wings.duplicate()
		return
	var length: int = _plane_length(index)
	_wings[index] = Wing.NONE
	_try_wings(index + 1, singles, pairs, absorbed, low)
	if _rules.single_wings_allowed():
		_try_kind(index, Wing.SINGLES, length, singles, pairs, absorbed, low)
		if _rules.single_wings_may_pair() and length % HandDecomposer.PAIR_WIDTH == 0:
			@warning_ignore("integer_division")
			var slots: int = length / HandDecomposer.PAIR_WIDTH
			_try_kind(index, Wing.PAIRS_IN_SINGLE_SLOTS, slots, singles, pairs, absorbed, low)
	if _rules.pair_wings_allowed():
		_try_kind(index, Wing.PAIRS, length, singles, pairs, absorbed, low)


func _try_kind(
	index: int,
	kind: Wing,
	slots: int,
	singles: PackedByteArray,
	pairs: PackedByteArray,
	absorbed: int,
	low: int
) -> void:
	var from_singles: bool = kind == Wing.SINGLES
	var pool: PackedByteArray = singles.duplicate() if from_singles else pairs.duplicate()
	var taken: PackedByteArray = _take_wings(index, pool, slots)
	if taken.size() < slots:
		return
	_wings[index] = kind
	if from_singles:
		var low_taken: int = 0
		for rank: int in taken:
			if _rank_map[rank] < _rank_map[LOW_LIMIT_RANK]:
				low_taken += 1
		_try_wings(index + 1, pool, pairs, absorbed + slots, low + low_taken)
	else:
		_try_wings(index + 1, singles, pool, absorbed + slots, low)


## Moves the lowest allowed ranks out of the pool. Wings differ from the airplane's ranks.
func _take_wings(index: int, pool: PackedByteArray, slots: int) -> PackedByteArray:
	var start: int = _plane_start(index)
	var length: int = _plane_length(index)
	var taken: PackedByteArray = PackedByteArray()
	var position: int = 0
	while position < pool.size() and taken.size() < slots:
		var rank: int = pool[position]
		var in_chain: bool = rank >= start and rank < start + length
		var barred: bool = rank >= Ranks.TWO and not _rules.joker_or_two_may_be_wing()
		if in_chain or barred:
			position += 1
		else:
			taken.append(rank)
			pool.remove_at(position)
	return taken


func _plane_start(index: int) -> int:
	return _planes[index] >> HandDecomposer.PLANE_LENGTH_SHIFT


func _plane_length(index: int) -> int:
	return _planes[index] & ((1 << HandDecomposer.PLANE_LENGTH_SHIFT) - 1)


func _loose_singles() -> PackedByteArray:
	var pool: PackedByteArray = _singles.duplicate()
	for index: int in _planes.size():
		if _best_wings[index] == Wing.SINGLES:
			_take_wings(index, pool, _plane_length(index))
	return pool


func _loose_pairs() -> PackedByteArray:
	var pool: PackedByteArray = _pairs.duplicate()
	for index: int in _planes.size():
		if _best_wings[index] != Wing.NONE and _best_wings[index] != Wing.SINGLES:
			_take_wings(index, pool, _wing_slots(index))
	return pool


func _wing_slots(index: int) -> int:
	if _best_wings[index] == Wing.PAIRS_IN_SINGLE_SLOTS:
		@warning_ignore("integer_division")
		return _plane_length(index) / HandDecomposer.PAIR_WIDTH
	return _plane_length(index)


func _plane_group(index: int) -> Pattern:
	var start: int = _plane_start(index)
	var length: int = _plane_length(index)
	var body: int = length * HandDecomposer.TRIO_WIDTH
	var kind: int = _best_wings[index]
	if kind == Wing.NONE:
		return _group(Pattern.Type.AIRPLANE, start, length, body)
	var from_singles: bool = kind == Wing.SINGLES
	var pool: PackedByteArray = _singles.duplicate() if from_singles else _pairs.duplicate()
	for earlier: int in index:
		var earlier_kind: int = _best_wings[earlier]
		if earlier_kind != Wing.NONE and (earlier_kind == Wing.SINGLES) == from_singles:
			_take_wings(earlier, pool, _wing_slots(earlier))
	var kickers: PackedByteArray = PackedByteArray()
	for rank: int in _take_wings(index, pool, _wing_slots(index)):
		kickers.append(rank)
		if not from_singles:
			kickers.append(rank)
	var type: Pattern.Type = Pattern.Type.AIRPLANE_PAIRS
	if kind != Wing.PAIRS:
		type = Pattern.Type.AIRPLANE_SINGLES
	return Pattern.new(type, start, length, body + kickers.size(), kickers, _rank_map[start])


func _trio(rank: int, type: Pattern.Type, kicker: int, width: int) -> Pattern:
	var kickers: PackedByteArray = PackedByteArray()
	kickers.resize(width)
	kickers.fill(kicker)
	var cards: int = HandDecomposer.TRIO_WIDTH + width
	return Pattern.new(type, rank, 1, cards, kickers, _rank_map[rank])


func _group(type: Pattern.Type, main: int, chain: int, cards: int) -> Pattern:
	return Pattern.new(type, main, chain, cards, PackedByteArray(), _rank_map[main])
