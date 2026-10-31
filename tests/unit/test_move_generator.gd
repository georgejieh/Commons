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


func _random_play(stream: RandomStream) -> Pattern:
	var counts: PackedByteArray = _random_counts(stream, FULL_HAND)
	var moves: Array[Pattern] = MoveGenerator.generate(
		counts, MoveReference.mask_of(counts), null, _rules, _map
	)
	return moves[stream.next_int(0, moves.size() - 1)]


func test_output_equals_the_brute_force_reference() -> void:
	var stream: RandomStream = RandomStream.new(SEED)
	var mismatches: int = 0
	for index: int in REFERENCE_HANDS:
		var cards: int = stream.next_int(1, MAX_REFERENCE_CARDS)
		var counts: PackedByteArray = _random_counts(stream, cards)
		var current: Pattern = null if index % 2 == 0 else _random_play(stream)
		var moves: Array[Pattern] = MoveReference.generated(counts, current, _rules, _map)
		var expected: Dictionary[int, bool] = MoveReference.expected_moves(
			counts, current, _rules, _map
		)
		var actual: Dictionary[int, bool] = MoveReference.identities(moves)
		if expected != actual or actual.size() != moves.size():
			mismatches += 1
	assert_int(mismatches).is_equal(0)


func test_following_includes_bombs_and_the_rocket() -> void:
	var counts: PackedByteArray = RankText.counts("3333sb4")
	var current: Pattern = Classifier.classify(RankText.counts("2"), _rules, _map).pattern
	var types: Array[int] = []
	var moves: Array[Pattern] = MoveGenerator.generate(
		counts, MoveReference.mask_of(counts), current, _rules, _map
	)
	for move: Pattern in moves:
		types.append(move.type)
	assert_bool(types.has(Pattern.Type.BOMB)).is_true()
	assert_bool(types.has(Pattern.Type.ROCKET)).is_true()
	assert_bool(types.has(Pattern.Type.SINGLE)).is_true()


func _median_usec(stream: RandomStream, following: bool) -> int:
	var times: Array[int] = []
	for _index: int in TIMED_HANDS:
		var counts: PackedByteArray = _random_counts(stream, FULL_HAND)
		var mask: int = MoveReference.mask_of(counts)
		var current: Pattern = _random_play(stream) if following else null
		var started: int = Time.get_ticks_usec()
		MoveGenerator.generate(counts, mask, current, _rules, _map)
		times.append(Time.get_ticks_usec() - started)
	times.sort()
	return times[TIMED_HANDS >> 1]


func test_median_time_for_a_full_hand_is_inside_the_budget() -> void:
	var stream: RandomStream = RandomStream.new(SEED)
	var leading: int = _median_usec(stream, false)
	var following: int = _median_usec(stream, true)
	print("Move generation median: lead %d usec, follow %d usec" % [leading, following])
	assert_int(leading).is_less(BUDGET_USEC)
	assert_int(following).is_less(BUDGET_USEC)
