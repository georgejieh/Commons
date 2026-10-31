extends GdUnitTestSuite
## Legal moves equal a brute-force reference, and stay inside the time budget.

const SEED: int = 1502
const REFERENCE_HANDS: int = 10000
const MAX_REFERENCE_CARDS: int = 12
const TIMED_HANDS: int = 400
const FULL_HAND: int = 20
const BUDGET_USEC: int = 1000

var _rules: RuleSet = RuleSet.default_rules()
var _map: PackedByteArray = Ranks.identity_map()


func _random_counts(stream: RandomStream, cards: int) -> PackedByteArray:
	var deck: PackedInt32Array = Deck.generate()
	var result: PackedByteArray = PackedByteArray()
	result.resize(Ranks.COUNT)
	for index: int in cards:
		var pick: int = stream.next_int(index, deck.size() - 1)
		var card: int = deck[pick]
		deck[pick] = deck[index]
		deck[index] = card
		result[Deck.rank_of(card)] += 1
	return result


func _mask_of(counts: PackedByteArray) -> int:
	var mask: int = 0
	for rank: int in Ranks.COUNT:
		if counts[rank] > 0:
			mask |= 1 << rank
	return mask


## Tries every sub-multiset of the hand through the classifier.
func _reference(counts: PackedByteArray, current: Pattern) -> Dictionary[int, bool]:
	var found: Dictionary[int, bool] = {}
	var picked: PackedByteArray = PackedByteArray()
	picked.resize(Ranks.COUNT)
	while true:
		var result: Classification = Classifier.classify(picked, _rules, _map)
		if result.is_valid():
			if current == null or PlayComparator.beats(result.pattern, current, _rules):
				found[result.pattern.identity()] = true
		var rank: int = 0
		while rank < Ranks.COUNT and picked[rank] == counts[rank]:
			picked[rank] = 0
			rank += 1
		if rank == Ranks.COUNT:
			return found
		picked[rank] += 1
	return found


func _generated(counts: PackedByteArray, current: Pattern) -> Dictionary[int, bool]:
	var found: Dictionary[int, bool] = {}
	var moves: Array[Pattern] = MoveGenerator.generate(
		counts, _mask_of(counts), current, _rules, _map
	)
	for move: Pattern in moves:
		assert_bool(found.has(move.identity())).is_false()
		found[move.identity()] = true
	return found


func _random_play(stream: RandomStream) -> Pattern:
	var counts: PackedByteArray = _random_counts(stream, FULL_HAND)
	var moves: Array[Pattern] = MoveGenerator.generate(counts, _mask_of(counts), null, _rules, _map)
	return moves[stream.next_int(0, moves.size() - 1)]


func test_output_equals_the_brute_force_reference() -> void:
	var stream: RandomStream = RandomStream.new(SEED)
	var mismatches: int = 0
	for index: int in REFERENCE_HANDS:
		var cards: int = stream.next_int(1, MAX_REFERENCE_CARDS)
		var counts: PackedByteArray = _random_counts(stream, cards)
		var current: Pattern = null if index % 2 == 0 else _random_play(stream)
		var expected: Dictionary[int, bool] = _reference(counts, current)
		var actual: Dictionary[int, bool] = _generated(counts, current)
		if expected != actual:
			mismatches += 1
	assert_int(mismatches).is_equal(0)


func test_output_order_is_deterministic() -> void:
	var counts: PackedByteArray = RankText.counts("333444555678JQK22")
	var first: Array[Pattern] = MoveGenerator.generate(counts, _mask_of(counts), null, _rules, _map)
	var second: Array[Pattern] = MoveGenerator.generate(
		counts, _mask_of(counts), null, _rules, _map
	)
	assert_int(first.size()).is_equal(second.size())
	for index: int in first.size():
		assert_int(first[index].identity()).is_equal(second[index].identity())


func test_following_includes_bombs_and_the_rocket() -> void:
	var counts: PackedByteArray = RankText.counts("3333sb4")
	var current: Pattern = Classifier.classify(RankText.counts("2"), _rules, _map).pattern
	var types: Array[int] = []
	var moves: Array[Pattern] = MoveGenerator.generate(
		counts, _mask_of(counts), current, _rules, _map
	)
	for move: Pattern in moves:
		types.append(move.type)
	assert_bool(types.has(Pattern.Type.BOMB)).is_true()
	assert_bool(types.has(Pattern.Type.ROCKET)).is_true()
	assert_bool(types.has(Pattern.Type.SINGLE)).is_true()


func test_median_time_for_a_full_hand_is_inside_the_budget() -> void:
	var stream: RandomStream = RandomStream.new(SEED)
	var times: Array[int] = []
	for index: int in TIMED_HANDS:
		var counts: PackedByteArray = _random_counts(stream, FULL_HAND)
		var mask: int = _mask_of(counts)
		var current: Pattern = null if index % 2 == 0 else _random_play(stream)
		var started: int = Time.get_ticks_usec()
		MoveGenerator.generate(counts, mask, current, _rules, _map)
		times.append(Time.get_ticks_usec() - started)
	times.sort()
	var median: int = times[TIMED_HANDS >> 1]
	print("Move generation median: %d usec, worst: %d usec" % [median, times[-1]])
	assert_int(median).is_less(BUDGET_USEC)
