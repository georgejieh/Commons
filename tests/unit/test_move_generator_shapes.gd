extends GdUnitTestSuite
## Random small hands rarely hold chains, so these build them on purpose, up to 20 cards,
## and also vary the rules and rank maps.

const SEED: int = 1505
const SHAPED_HANDS: int = 300
const MIXED_HANDS: int = 400
const MAX_CARDS: int = 20
const MAX_COPIES: int = 4
const MIN_RUN: int = 2
const MAX_RUN: int = 5
const LONG_AIRPLANE: int = 3
const TYPE_TRIES: int = 30
const REPLY_TYPES: Array[Pattern.Type] = [
	Pattern.Type.SINGLE,
	Pattern.Type.PAIR,
	Pattern.Type.TRIO,
	Pattern.Type.TRIO_SINGLE,
	Pattern.Type.TRIO_PAIR,
	Pattern.Type.STRAIGHT,
	Pattern.Type.PAIR_CHAIN,
	Pattern.Type.AIRPLANE,
	Pattern.Type.AIRPLANE_SINGLES,
	Pattern.Type.AIRPLANE_PAIRS,
	Pattern.Type.FOUR_TWO_SINGLES,
	Pattern.Type.FOUR_TWO_PAIRS,
	Pattern.Type.BOMB,
]

var _rules: RuleSet = RuleSet.default_rules()
var _map: PackedByteArray = Ranks.identity_map()


## Builds a run of width-card groups, then fills with random cards.
func _shaped_counts(stream: RandomStream, max_copies: int = MAX_COPIES) -> PackedByteArray:
	var counts: PackedByteArray = PackedByteArray()
	counts.resize(Ranks.COUNT)
	var width: int = stream.next_int(1, MAX_COPIES)
	var length: int = stream.next_int(MIN_RUN, MAX_RUN)
	var start: int = stream.next_int(0, Ranks.ACE + 1 - length)
	for offset: int in length:
		counts[start + offset] = width
	var cards: int = width * length
	var target: int = stream.next_int(cards, MAX_CARDS)
	while cards < target:
		var rank: int = stream.next_int(0, Ranks.COUNT - 1)
		var limit: int = 1 if rank >= Ranks.SMALL_JOKER and max_copies == MAX_COPIES else max_copies
		if counts[rank] < limit:
			counts[rank] += 1
			cards += 1
	return counts


## Returns a play of the type from a shaped hand, lowest ranks first so replies exist.
func _current_of_type(stream: RandomStream, type: Pattern.Type) -> Pattern:
	for _try: int in TYPE_TRIES:
		var moves: Array[Pattern] = MoveReference.generated(
			_shaped_counts(stream), null, _rules, _map
		)
		for move: Pattern in moves:
			if move.type == type:
				return move
	return null


func _random_current(stream: RandomStream, rules: RuleSet, map: PackedByteArray) -> Pattern:
	var moves: Array[Pattern] = MoveReference.generated(_shaped_counts(stream), null, rules, map)
	return moves[stream.next_int(0, moves.size() - 1)]


func _is_match(
	counts: PackedByteArray, current: Pattern, rules: RuleSet, map: PackedByteArray
) -> bool:
	var moves: Array[Pattern] = MoveReference.generated(counts, current, rules, map)
	var expected: Dictionary[int, bool] = MoveReference.expected_moves(counts, current, rules, map)
	var actual: Dictionary[int, bool] = MoveReference.identities(moves)
	return actual.size() == moves.size() and actual == expected


func test_shaped_hands_equal_the_reference_and_reach_every_shape() -> void:
	var stream: RandomStream = RandomStream.new(SEED)
	var mismatches: int = 0
	var replies: Dictionary[int, bool] = {}
	var long_airplanes: Dictionary[int, bool] = {}
	for index: int in SHAPED_HANDS:
		var counts: PackedByteArray = _shaped_counts(stream)
		var type: Pattern.Type = REPLY_TYPES[index % REPLY_TYPES.size()]
		var current: Pattern = null if index % 3 == 0 else _current_of_type(stream, type)
		if not _is_match(counts, current, _rules, _map):
			mismatches += 1
		for move: Pattern in MoveReference.generated(counts, current, _rules, _map):
			if current != null and move.type == current.type:
				replies[move.type] = true
			if move.chain_length >= LONG_AIRPLANE:
				long_airplanes[move.type] = true
	assert_int(mismatches).is_equal(0)
	for type: Pattern.Type in REPLY_TYPES:
		assert_bool(replies.has(type)).override_failure_message(str(type)).is_true()
	assert_bool(long_airplanes.has(Pattern.Type.AIRPLANE_SINGLES)).is_true()
	assert_bool(long_airplanes.has(Pattern.Type.AIRPLANE_PAIRS)).is_true()


func _edited(field: String, value: Variant) -> RuleSet:
	var params: RuleParams = RuleSet.DEFAULT_PARAMS.duplicate()
	params.set(field, value)
	return RuleSet.new(params)


func _varied_rules() -> Array[RuleSet]:
	return [
		_edited("five_plus_is_bomb", true),
		_edited("two_may_chain", true),
		_edited("four_two_singles_may_share_rank", true),
		_edited("single_wings_may_pair", false),
		_edited("rocket_may_be_kicker", true),
		_edited("joker_or_two_may_be_wing", false),
		_edited("single_wings_allowed", false),
		_edited("pair_wings_allowed", false),
		_edited("four_two_singles_allowed", false),
		_edited("four_two_pairs_allowed", false),
		_edited("min_straight_length", 3),
	]


func _varied_maps() -> Array[PackedByteArray]:
	var reversed_map: PackedByteArray = Ranks.identity_map()
	reversed_map.reverse()
	var promoted: PackedByteArray = Ranks.identity_map()
	promoted[Ranks.THREE] = Ranks.TWO
	return [_map, reversed_map, promoted]


func test_varied_rules_and_maps_equal_the_reference() -> void:
	var stream: RandomStream = RandomStream.new(SEED + 1)
	var rule_sets: Array[RuleSet] = _varied_rules()
	var maps: Array[PackedByteArray] = _varied_maps()
	var mismatches: int = 0
	for index: int in MIXED_HANDS:
		var rules: RuleSet = rule_sets[index % rule_sets.size()]
		var map: PackedByteArray = maps[index % maps.size()]
		var copies: int = MAX_COPIES + (index % 2)
		var counts: PackedByteArray = _shaped_counts(stream, copies)
		var current: Pattern = null if index % 3 == 0 else _random_current(stream, rules, map)
		if not _is_match(counts, current, rules, map):
			mismatches += 1
	assert_int(mismatches).is_equal(0)


func test_a_large_winged_airplane_is_offered() -> void:
	var counts: PackedByteArray = RankText.counts("333444555667788")
	var descriptions: Array[String] = []
	for move: Pattern in MoveReference.generated(counts, null, _rules, _map):
		descriptions.append(RankText.describe(move))
	assert_array(descriptions).contains(["AIRPLANE_PAIRS 3 x3 667788"])


func test_lead_order_is_pinned() -> void:
	var counts: PackedByteArray = RankText.counts("3344")
	var descriptions: Array[String] = []
	for move: Pattern in MoveReference.generated(counts, null, _rules, _map):
		descriptions.append(RankText.describe(move))
	assert_array(descriptions).is_equal(
		["SINGLE 3 x1 ", "SINGLE 4 x1 ", "PAIR 3 x1 ", "PAIR 4 x1 "]
	)


func test_follow_order_is_pinned() -> void:
	var counts: PackedByteArray = RankText.counts("9TTTT2sb")
	var current: Pattern = Classifier.classify(RankText.counts("8"), _rules, _map).pattern
	var descriptions: Array[String] = []
	for move: Pattern in MoveReference.generated(counts, current, _rules, _map):
		descriptions.append(RankText.describe(move))
	(
		assert_array(descriptions)
		. is_equal(
			[
				"SINGLE 9 x1 ",
				"SINGLE T x1 ",
				"SINGLE 2 x1 ",
				"SINGLE s x1 ",
				"SINGLE b x1 ",
				"BOMB T x1 ",
				"ROCKET s x1 ",
			]
		)
	)
