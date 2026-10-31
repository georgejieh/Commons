class_name MoveGenerator
extends RefCounted
## Lists every legal play for a hand, over ranks rather than card instances, in a fixed
## order. A chain is a sliding window over chainable ranks, and kickers are rank
## combinations, so suits never multiply the branching.

const SINGLE_WIDTH: int = 1
const PAIR_WIDTH: int = 2
const TRIO_WIDTH: int = 3
const QUAD_WIDTH: int = 4
const FOUR_TWO_KICKERS: int = 2
const ANY_LENGTH: int = 0
const NO_FLOOR: int = -1

var _counts: PackedByteArray
var _rules: RuleSet
var _rank_map: PackedByteArray
var _present: PackedByteArray = PackedByteArray()
## A play's main rank must map above this to be worth building.
var _floor: int = NO_FLOOR
var _moves: Array[Pattern] = []


func _init(
	counts: PackedByteArray, rank_mask: int, rules: RuleSet, rank_map: PackedByteArray
) -> void:
	_counts = counts
	_rules = rules
	_rank_map = rank_map
	for rank: int in Ranks.COUNT:
		if rank_mask & (1 << rank) != 0:
			_present.append(rank)


## Pass null for current when leading. A pass is never listed.
static func generate(
	counts: PackedByteArray,
	rank_mask: int,
	current: Pattern,
	rules: RuleSet,
	rank_map: PackedByteArray
) -> Array[Pattern]:
	var generator: MoveGenerator = MoveGenerator.new(counts, rank_mask, rules, rank_map)
	if current == null:
		generator._lead()
	else:
		generator._follow(current)
	return generator._moves


func _lead() -> void:
	_rank_groups(Pattern.Type.SINGLE, SINGLE_WIDTH)
	_rank_groups(Pattern.Type.PAIR, PAIR_WIDTH)
	_rank_groups(Pattern.Type.TRIO, TRIO_WIDTH)
	_trios_with_kicker(Pattern.Type.TRIO_SINGLE, SINGLE_WIDTH)
	_trios_with_kicker(Pattern.Type.TRIO_PAIR, PAIR_WIDTH)
	_chains(Pattern.Type.STRAIGHT, SINGLE_WIDTH, _rules.min_straight_length(), ANY_LENGTH)
	_chains(Pattern.Type.PAIR_CHAIN, PAIR_WIDTH, _rules.min_pair_chain_length(), ANY_LENGTH)
	_chains(Pattern.Type.AIRPLANE, TRIO_WIDTH, _rules.min_airplane_length(), ANY_LENGTH)
	_chains(Pattern.Type.AIRPLANE_SINGLES, TRIO_WIDTH, _rules.min_airplane_length(), ANY_LENGTH)
	_chains(Pattern.Type.AIRPLANE_PAIRS, TRIO_WIDTH, _rules.min_airplane_length(), ANY_LENGTH)
	_four_two_singles()
	_four_two_pairs()
	_bombs(null)
	_rocket(null)


func _follow(current: Pattern) -> void:
	_floor = current.key & ((1 << Pattern.KEY_RANK_BITS) - 1)
	var length: int = current.chain_length
	match current.type:
		Pattern.Type.SINGLE:
			_rank_groups(Pattern.Type.SINGLE, SINGLE_WIDTH)
		Pattern.Type.PAIR:
			_rank_groups(Pattern.Type.PAIR, PAIR_WIDTH)
		Pattern.Type.TRIO:
			_rank_groups(Pattern.Type.TRIO, TRIO_WIDTH)
		Pattern.Type.TRIO_SINGLE:
			_trios_with_kicker(Pattern.Type.TRIO_SINGLE, SINGLE_WIDTH)
		Pattern.Type.TRIO_PAIR:
			_trios_with_kicker(Pattern.Type.TRIO_PAIR, PAIR_WIDTH)
		Pattern.Type.STRAIGHT:
			_chains(current.type, SINGLE_WIDTH, length, length)
		Pattern.Type.PAIR_CHAIN:
			_chains(current.type, PAIR_WIDTH, length, length)
		Pattern.Type.AIRPLANE, Pattern.Type.AIRPLANE_SINGLES, Pattern.Type.AIRPLANE_PAIRS:
			_chains(current.type, TRIO_WIDTH, length, length)
		Pattern.Type.FOUR_TWO_SINGLES:
			_four_two_singles()
		Pattern.Type.FOUR_TWO_PAIRS:
			_four_two_pairs()
	_floor = NO_FLOOR
	_bombs(current)
	_rocket(current)


func _rank_groups(type: Pattern.Type, width: int) -> void:
	for rank: int in _present:
		if _counts[rank] >= width and _rank_map[rank] > _floor:
			_add(type, rank, 1, width, PackedByteArray())


func _trios_with_kicker(type: Pattern.Type, width: int) -> void:
	for rank: int in _present:
		if _counts[rank] < TRIO_WIDTH or _rank_map[rank] <= _floor:
			continue
		for kicker: int in _present:
			if kicker != rank and _counts[kicker] >= width:
				var kickers: PackedByteArray = PackedByteArray()
				kickers.resize(width)
				kickers.fill(kicker)
				_add(type, rank, 1, TRIO_WIDTH + width, kickers)


func _chains(type: Pattern.Type, width: int, minimum: int, fixed_length: int) -> void:
	var last: int = _rules.last_chain_rank()
	for start: int in last + 1:
		if _rank_map[start] <= _floor:
			continue
		var length: int = 0
		while start + length <= last and _counts[start + length] >= width:
			length += 1
			if length >= minimum and (fixed_length == ANY_LENGTH or length == fixed_length):
				_chain_at(type, start, length, width)


func _chain_at(type: Pattern.Type, start: int, length: int, width: int) -> void:
	var body: int = width * length
	match type:
		Pattern.Type.AIRPLANE_SINGLES:
			_single_wings(start, length, body)
		Pattern.Type.AIRPLANE_PAIRS:
			if _rules.pair_wings_allowed():
				var pool: PackedByteArray = _wing_pool(start, length, PAIR_WIDTH)
				_kicker_sets(type, start, length, body, pool, length, PAIR_WIDTH)
		_:
			_add(type, start, length, body, PackedByteArray())


func _single_wings(start: int, length: int, body: int) -> void:
	if not _rules.single_wings_allowed():
		return
	var type: Pattern.Type = Pattern.Type.AIRPLANE_SINGLES
	var pool: PackedByteArray = _wing_pool(start, length, SINGLE_WIDTH)
	_kicker_sets(type, start, length, body, pool, length, SINGLE_WIDTH)
	if _rules.single_wings_may_pair() and length % PAIR_WIDTH == 0:
		@warning_ignore("integer_division")
		var pair_slots: int = length / PAIR_WIDTH
		var pairs: PackedByteArray = _wing_pool(start, length, PAIR_WIDTH)
		_kicker_sets(type, start, length, body, pairs, pair_slots, PAIR_WIDTH)


## Returns the ranks outside the chain that hold enough cards to be a wing.
func _wing_pool(start: int, length: int, width: int) -> PackedByteArray:
	var pool: PackedByteArray = PackedByteArray()
	for rank: int in _present:
		var in_chain: bool = rank >= start and rank < start + length
		if in_chain or _counts[rank] < width:
			continue
		if rank >= Ranks.TWO and not _rules.joker_or_two_may_be_wing():
			continue
		pool.append(rank)
	return pool


## Adds one play per way to pick slots ranks from the pool, each repeated width times.
func _kicker_sets(
	type: Pattern.Type,
	main: int,
	chain: int,
	body: int,
	pool: PackedByteArray,
	slots: int,
	width: int
) -> void:
	var picks: PackedInt32Array = PackedInt32Array()
	picks.resize(slots)
	var depth: int = 0
	var next: int = 0
	while depth >= 0:
		if depth == slots:
			_add_kicker_set(type, main, chain, body, pool, picks, width)
			depth -= 1
			if depth >= 0:
				next = picks[depth] + 1
		elif next > pool.size() - (slots - depth):
			depth -= 1
			if depth >= 0:
				next = picks[depth] + 1
		else:
			picks[depth] = next
			depth += 1
			next += 1


func _add_kicker_set(
	type: Pattern.Type,
	main: int,
	chain: int,
	body: int,
	pool: PackedByteArray,
	picks: PackedInt32Array,
	width: int
) -> void:
	var kickers: PackedByteArray = PackedByteArray()
	var mask: int = 0
	for pick: int in picks:
		var rank: int = pool[pick]
		mask |= 1 << rank
		for _copy: int in width:
			kickers.append(rank)
	if width == SINGLE_WIDTH and mask & Classifier.ROCKET_MASK == Classifier.ROCKET_MASK:
		if not _rules.rocket_may_be_kicker():
			return
	_add(type, main, chain, body + kickers.size(), kickers)


func _four_two_singles() -> void:
	if not _rules.four_two_singles_allowed():
		return
	var type: Pattern.Type = Pattern.Type.FOUR_TWO_SINGLES
	for rank: int in _present:
		if _counts[rank] < QUAD_WIDTH or _rank_map[rank] <= _floor:
			continue
		var pool: PackedByteArray = _kicker_pool(rank, SINGLE_WIDTH)
		_kicker_sets(type, rank, 1, QUAD_WIDTH, pool, FOUR_TWO_KICKERS, SINGLE_WIDTH)
		if _rules.four_two_singles_may_share_rank():
			var pairs: PackedByteArray = _kicker_pool(rank, PAIR_WIDTH)
			_kicker_sets(type, rank, 1, QUAD_WIDTH, pairs, 1, PAIR_WIDTH)


func _four_two_pairs() -> void:
	if not _rules.four_two_pairs_allowed():
		return
	var type: Pattern.Type = Pattern.Type.FOUR_TWO_PAIRS
	for rank: int in _present:
		if _counts[rank] >= QUAD_WIDTH and _rank_map[rank] > _floor:
			var pool: PackedByteArray = _kicker_pool(rank, PAIR_WIDTH)
			_kicker_sets(type, rank, 1, QUAD_WIDTH, pool, FOUR_TWO_KICKERS, PAIR_WIDTH)


func _kicker_pool(body_rank: int, width: int) -> PackedByteArray:
	var pool: PackedByteArray = PackedByteArray()
	for rank: int in _present:
		if rank != body_rank and _counts[rank] >= width:
			pool.append(rank)
	return pool


func _bombs(current: Pattern) -> void:
	for rank: int in _present:
		var largest: int = _counts[rank] if _rules.five_plus_is_bomb() else QUAD_WIDTH
		for size: int in range(QUAD_WIDTH, mini(largest, _counts[rank]) + 1):
			var bomb: Pattern = _build(Pattern.Type.BOMB, rank, 1, size, PackedByteArray())
			if current == null or PlayComparator.beats(bomb, current, _rules):
				_moves.append(bomb)


func _rocket(current: Pattern) -> void:
	if _counts[Ranks.SMALL_JOKER] == 0 or _counts[Ranks.BIG_JOKER] == 0:
		return
	var main: int = Ranks.SMALL_JOKER
	var rocket: Pattern = _build(Pattern.Type.ROCKET, main, 1, PAIR_WIDTH, PackedByteArray())
	if current == null or PlayComparator.beats(rocket, current, _rules):
		_moves.append(rocket)


func _add(type: Pattern.Type, main: int, chain: int, cards: int, kickers: PackedByteArray) -> void:
	_moves.append(_build(type, main, chain, cards, kickers))


func _build(
	type: Pattern.Type, main: int, chain: int, cards: int, kickers: PackedByteArray
) -> Pattern:
	return Pattern.new(type, main, chain, cards, kickers, _rank_map[main])
