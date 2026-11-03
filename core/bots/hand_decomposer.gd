class_name HandDecomposer
extends RefCounted
## Finds the fewest plays that empty a hand, by depth-first search over chains.
## At the lowest rank not yet settled, the search starts each chain there or settles the
## rank as outside any chain. What is left when no rank remains is counted in closed form.
## Scores add up along a path, so a lower score is simply better: fewer hands, then fewer
## low singles, then more group strength. Keep one instance for one decision, so all its
## candidates share the memo, and clear it for the next. Quads stay bombs unless a chain
## takes from them, and trios stay whole, so neither is ever spent as kickers.

const POSITION_SHIFT: int = 60
const HAND_SHIFT: int = 32
const LOW_SINGLE_SHIFT: int = 16
const STRENGTH_SPAN: int = 1 << LOW_SINGLE_SHIFT
const LOW_FIELD_MASK: int = (1 << (HAND_SHIFT - LOW_SINGLE_SHIFT)) - 1
const NO_SCORE: int = 1 << 56
const PLANE_LENGTH_SHIFT: int = 4
const PLANE_CODE_SHIFT: int = 8
const SINGLE_WIDTH: int = 1
const PAIR_WIDTH: int = 2
const TRIO_WIDTH: int = 3
const BOMB_WIDTH: int = 4

var _rules: RuleSet
var _rank_map: PackedByteArray
var _cap: int
var _last: int
var _counts: PackedByteArray
## One memo per set of airplanes taken, because wings depend on them.
var _memos: Dictionary[int, Dictionary] = {}
var _stored: int = 0
var _planes: PackedInt32Array = PackedInt32Array()
var _leaf: DecompositionLeaf


func _init(rules: RuleSet, rank_map: PackedByteArray, memo_cap: int) -> void:
	_rules = rules
	_rank_map = rank_map
	_cap = memo_cap
	_last = rules.last_chain_rank()
	_leaf = DecompositionLeaf.new(rules, rank_map)


static func hands_in(score_value: int) -> int:
	return (score_value + STRENGTH_SPAN - 1) >> HAND_SHIFT


static func low_singles_in(score_value: int) -> int:
	return ((score_value + STRENGTH_SPAN - 1) >> LOW_SINGLE_SHIFT) & LOW_FIELD_MASK


func clear() -> void:
	_memos.clear()
	_stored = 0


## Positions remembered now. Never above the cap.
func memo_size() -> int:
	return _stored


## Returns the hand's score, without building its groups.
func score(counts: PackedByteArray) -> int:
	_counts = counts.duplicate()
	_planes.clear()
	return _search(0, CountKey.encode(_counts), 0)


func decompose(counts: PackedByteArray) -> Decomposition:
	var low: int = low_singles_in(score(counts))
	var groups: Array[Pattern] = []
	_walk(0, CountKey.encode(_counts), 0, groups)
	return Decomposition.new(groups, low)


func _search(position: int, key: int, plane_code: int) -> int:
	while position <= _last and _counts[position] == 0:
		position += 1
	var memo_key: int = key | (position << POSITION_SHIFT)
	if not _memos.has(plane_code):
		_memos[plane_code] = {}
	var memo: Dictionary = _memos[plane_code]
	if memo.has(memo_key):
		return memo[memo_key]
	var best: int
	if position > _last:
		best = _leaf.read(_counts, _planes).score
	else:
		best = mini(_search(position + 1, key, plane_code), _chains_at(position, key, plane_code))
	if _stored < _cap:
		memo[memo_key] = best
		_stored += 1
	return best


func _chains_at(start: int, key: int, plane_code: int) -> int:
	var best: int = NO_SCORE
	for width: int in range(SINGLE_WIDTH, TRIO_WIDTH + 1):
		var length: int = 0
		var minimum: int = _minimum_length(width)
		var chain_key: int = key
		while start + length <= _last and _counts[start + length] >= width:
			_counts[start + length] -= width
			chain_key -= width << ((start + length) * CountKey.BITS_PER_RANK)
			length += 1
			if length >= minimum:
				best = mini(best, _after_chain(start, length, width, chain_key, plane_code))
		for rank: int in range(start, start + length):
			_counts[rank] += width
	return best


func _after_chain(start: int, length: int, width: int, key: int, plane_code: int) -> int:
	var chain: int = (1 << HAND_SHIFT) - _rank_map[start]
	if width != TRIO_WIDTH:
		return chain + _search(start, key, plane_code)
	_planes.append((start << PLANE_LENGTH_SHIFT) | length)
	var rest: int = _search(start, key, _code_with(plane_code))
	_planes.resize(_planes.size() - 1)
	return chain + rest


func _minimum_length(width: int) -> int:
	match width:
		SINGLE_WIDTH:
			return _rules.min_straight_length()
		PAIR_WIDTH:
			return _rules.min_pair_chain_length()
	return _rules.min_airplane_length()


func _code_with(plane_code: int) -> int:
	return (plane_code << PLANE_CODE_SHIFT) | _planes[-1]


## Follows the choices that reach the best score, adding each chain and the leaf's groups.
func _walk(position: int, key: int, plane_code: int, groups: Array[Pattern]) -> void:
	var target: int = _search(position, key, plane_code)
	while position <= _last and _counts[position] == 0:
		position += 1
	if position > _last:
		groups.append_array(_leaf.groups(_counts, _planes))
	elif _search(position + 1, key, plane_code) == target:
		_walk(position + 1, key, plane_code, groups)
	else:
		_walk_chain(position, key, plane_code, target, groups)


func _walk_chain(
	start: int, key: int, plane_code: int, target: int, groups: Array[Pattern]
) -> void:
	for width: int in range(SINGLE_WIDTH, TRIO_WIDTH + 1):
		var length: int = 0
		var chain_key: int = key
		while start + length <= _last and _counts[start + length] >= width:
			_counts[start + length] -= width
			chain_key -= width << ((start + length) * CountKey.BITS_PER_RANK)
			length += 1
			if length < _minimum_length(width):
				continue
			if _after_chain(start, length, width, chain_key, plane_code) == target:
				_keep_chain(start, length, width, chain_key, plane_code, groups)
				return
		for rank: int in range(start, start + length):
			_counts[rank] += width


func _keep_chain(
	start: int, length: int, width: int, key: int, plane_code: int, groups: Array[Pattern]
) -> void:
	if width == TRIO_WIDTH:
		_planes.append((start << PLANE_LENGTH_SHIFT) | length)
		_walk(start, key, _code_with(plane_code), groups)
		return
	var type: Pattern.Type = Pattern.Type.STRAIGHT
	if width == PAIR_WIDTH:
		type = Pattern.Type.PAIR_CHAIN
	var kickers: PackedByteArray = PackedByteArray()
	groups.append(Pattern.new(type, start, length, length * width, kickers, _rank_map[start]))
	_walk(start, key, plane_code, groups)
