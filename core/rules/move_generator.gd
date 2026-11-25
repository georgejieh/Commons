class_name MoveGenerator
extends RefCounted
## Lists every legal play for a hand, over ranks rather than card instances, in a fixed
## order. A chain is a sliding window over chainable ranks, and kickers are rank
## combinations, so suits never multiply the branching. With wild cards in the hand
## (ADR 0029) every rank can take them, each reading is listed once with the cards
## WildSupply spends for it, and a kicker made of wild cards alone reads as the first rank
## WildSupply offers, so readings that differ only in such a kicker are not repeated.
## Lean generation, for bots, leaves out every play WildSupply.is_lean() refuses unbuilt.

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
## Null when the hand holds no wild card.
var _supply: WildSupply = null
## When above zero, only plays of exactly this many cards: the readings of one set.
var _target: int = 0


func _init(
	counts: PackedByteArray, rank_mask: int, rules: RuleSet, rank_map: PackedByteArray
) -> void:
	_counts = counts
	_rules = rules
	_rank_map = rank_map
	_supply = WildSupply.of(counts, rules)
	var mask: int = rank_mask
	if _supply != null:
		_counts = _supply.available()
		for rank: int in Ranks.COUNT:
			mask |= (1 << rank) if _counts[rank] > 0 else 0
	for rank: int in Ranks.COUNT:
		if mask & (1 << rank) != 0:
			_present.append(rank)


## Pass null for current when leading. A pass is never listed. lean leaves out the plays
## WildSupply.is_lean() refuses, which only a hand with a wild card has.
static func generate(
	counts: PackedByteArray,
	rank_mask: int,
	current: Pattern,
	rules: RuleSet,
	rank_map: PackedByteArray,
	lean: bool = false
) -> Array[Pattern]:
	var generator: MoveGenerator = MoveGenerator.new(counts, rank_mask, rules, rank_map)
	if generator._supply != null:
		generator._supply.lean = lean
	if current == null:
		generator._lead()
	else:
		generator._follow(current)
	return generator._moves


## Every reading of exactly these cards, in generation order, for cards that hold a wild
## card. Readings sorts the result and reads plain cards through the classifier.
static func exact(
	counts: PackedByteArray, rules: RuleSet, rank_map: PackedByteArray
) -> Array[Pattern]:
	var mask: int = 0
	var total: int = 0
	for rank: int in Ranks.COUNT:
		mask |= (1 << rank) if counts[rank] > 0 else 0
		total += counts[rank]
	var generator: MoveGenerator = MoveGenerator.new(counts, mask, rules, rank_map)
	generator._target = total
	generator._lead()
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
		# A chain answers only at a length the follower's own rules allow: a seat without
		# Shock Brigade has no 4-card Straight to answer one with (ADR 0039).
		Pattern.Type.STRAIGHT:
			_chains(current.type, SINGLE_WIDTH, maxi(length, _rules.min_straight_length()), length)
		Pattern.Type.PAIR_CHAIN:
			_chains(current.type, PAIR_WIDTH, maxi(length, _rules.min_pair_chain_length()), length)
		Pattern.Type.AIRPLANE, Pattern.Type.AIRPLANE_SINGLES, Pattern.Type.AIRPLANE_PAIRS:
			_chains(current.type, TRIO_WIDTH, maxi(length, _rules.min_airplane_length()), length)
		Pattern.Type.FOUR_TWO_SINGLES:
			_four_two_singles()
		Pattern.Type.FOUR_TWO_PAIRS:
			_four_two_pairs()
	_floor = NO_FLOOR
	_bombs(current)
	_rocket(current)


func _rank_groups(type: Pattern.Type, width: int) -> void:
	if not _fits(width):
		return
	for rank: int in _present:
		if _counts[rank] >= width and _rank_map[rank] > _floor:
			_add(type, rank, 1, width, PackedByteArray())


func _trios_with_kicker(type: Pattern.Type, width: int) -> void:
	if not _fits(TRIO_WIDTH + width):
		return
	for rank: int in _present:
		if _counts[rank] < TRIO_WIDTH or _rank_map[rank] <= _floor:
			continue
		_offer_wild_kickers(1 << rank, 1)
		for kicker: int in _present:
			if kicker == rank or _counts[kicker] < width or not _kicker_offered(kicker, 1):
				continue
			if _own_or_natural(kicker, width):
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
		var standing: int = 0
		while start + length <= last and _counts[start + length] >= width:
			if _supply != null:
				standing += maxi(0, width - _supply.natural[start + length])
				if standing > _supply.total:
					break
			length += 1
			if length >= minimum and (fixed_length == ANY_LENGTH or length == fixed_length):
				_chain_at(type, start, length, width)


func _chain_at(type: Pattern.Type, start: int, length: int, width: int) -> void:
	var body: int = width * length
	var wings: int = 0
	if type == Pattern.Type.AIRPLANE_SINGLES:
		wings = length
	elif type == Pattern.Type.AIRPLANE_PAIRS:
		wings = length * PAIR_WIDTH
	if not _fits(body + wings):
		return
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
	var excluded: int = ((1 << length) - 1) << start
	if not _rules.joker_or_two_may_be_wing():
		excluded |= ~((1 << Ranks.TWO) - 1)
	return _offered_pool(pool, excluded, length, width)


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
	var wild_alone: int = 0
	for pick: int in picks:
		var rank: int = pool[pick]
		if _supply != null and _supply.natural[rank] == 0:
			wild_alone += 1
		mask |= 1 << rank
		for _copy: int in width:
			kickers.append(rank)
	if width == SINGLE_WIDTH and mask & Classifier.ROCKET_MASK == Classifier.ROCKET_MASK:
		if not _rules.rocket_may_be_kicker():
			return
	# Kickers of wild cards alone take the offered ranks in order, so no two plays differ
	# only in what such a kicker reads as.
	for index: int in wild_alone:
		if mask & (1 << _supply.offered[index]) == 0:
			return
	_add(type, main, chain, body + kickers.size(), kickers)


func _four_two_singles() -> void:
	if not _rules.four_two_singles_allowed() or not _fits(QUAD_WIDTH + FOUR_TWO_KICKERS):
		return
	var type: Pattern.Type = Pattern.Type.FOUR_TWO_SINGLES
	for rank: int in _present:
		if _counts[rank] < QUAD_WIDTH or _rank_map[rank] <= _floor:
			continue
		if not _own_or_natural(rank, QUAD_WIDTH):
			continue
		var pool: PackedByteArray = _kicker_pool(rank, SINGLE_WIDTH)
		_kicker_sets(type, rank, 1, QUAD_WIDTH, pool, FOUR_TWO_KICKERS, SINGLE_WIDTH)
		if _rules.four_two_singles_may_share_rank():
			var pairs: PackedByteArray = _kicker_pool(rank, PAIR_WIDTH)
			_kicker_sets(type, rank, 1, QUAD_WIDTH, pairs, 1, PAIR_WIDTH)


func _four_two_pairs() -> void:
	var cards: int = QUAD_WIDTH + FOUR_TWO_KICKERS * PAIR_WIDTH
	if not _rules.four_two_pairs_allowed() or not _fits(cards):
		return
	var type: Pattern.Type = Pattern.Type.FOUR_TWO_PAIRS
	for rank: int in _present:
		var quad: bool = _counts[rank] >= QUAD_WIDTH and _own_or_natural(rank, QUAD_WIDTH)
		if quad and _rank_map[rank] > _floor:
			var pool: PackedByteArray = _kicker_pool(rank, PAIR_WIDTH)
			_kicker_sets(type, rank, 1, QUAD_WIDTH, pool, FOUR_TWO_KICKERS, PAIR_WIDTH)


func _kicker_pool(body_rank: int, width: int) -> PackedByteArray:
	var pool: PackedByteArray = PackedByteArray()
	for rank: int in _present:
		if rank != body_rank and _counts[rank] >= width:
			pool.append(rank)
	return _offered_pool(pool, 1 << body_rank, FOUR_TWO_KICKERS, width)


func _offered_pool(pool: PackedByteArray, excluded: int, slots: int, width: int) -> PackedByteArray:
	return pool if _supply == null else _supply.offered_pool(pool, excluded, slots, width)


func _own_or_natural(rank: int, width: int) -> bool:
	return _supply == null or _supply.fills_own(rank, width)


func _offer_wild_kickers(excluded: int, slots: int) -> void:
	if _supply != null:
		_supply.offer(excluded, slots)


func _kicker_offered(rank: int, slots: int) -> bool:
	return _supply == null or _supply.is_offered(rank, slots)


func _fits(cards: int) -> bool:
	return _target == 0 or cards == _target


func _bombs(current: Pattern) -> void:
	for rank: int in _present:
		var largest: int = _counts[rank] if _rules.five_plus_is_bomb() else QUAD_WIDTH
		for size: int in range(QUAD_WIDTH, mini(largest, _counts[rank]) + 1):
			if not _fits(size):
				continue
			var bomb: Pattern = _build(Pattern.Type.BOMB, rank, 1, size, PackedByteArray())
			if _spends(bomb) and (current == null or PlayComparator.beats(bomb, current, _rules)):
				_moves.append(bomb)


func _rocket(current: Pattern) -> void:
	if _counts[Ranks.SMALL_JOKER] == 0 or _counts[Ranks.BIG_JOKER] == 0 or not _fits(PAIR_WIDTH):
		return
	var main: int = Ranks.SMALL_JOKER
	var rocket: Pattern = _build(Pattern.Type.ROCKET, main, 1, PAIR_WIDTH, PackedByteArray())
	if _spends(rocket) and (current == null or PlayComparator.beats(rocket, current, _rules)):
		_moves.append(rocket)


func _add(type: Pattern.Type, main: int, chain: int, cards: int, kickers: PackedByteArray) -> void:
	if not _fits(cards):
		return
	var move: Pattern = _build(type, main, chain, cards, kickers)
	if _spends(move):
		_moves.append(move)


## With wild cards, records the cards the move spends, or returns false when the hand
## cannot spend it.
func _spends(move: Pattern) -> bool:
	if _supply == null:
		return true
	var reading: PackedByteArray = move.counts()
	var printed: PackedByteArray = _supply.fill(reading)
	if printed.is_empty():
		return false
	if printed != reading:
		move.spent = printed
	return true


func _build(
	type: Pattern.Type, main: int, chain: int, cards: int, kickers: PackedByteArray
) -> Pattern:
	return Pattern.new(type, main, chain, cards, kickers, _rank_map[main]).read_under(_rules)
