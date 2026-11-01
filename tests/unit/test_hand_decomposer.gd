extends GdUnitTestSuite
## Minimum-hands search against brute force, and its limits.

const CAP: int = 50000
const MEDIAN_LIMIT_USEC: int = 5000
const TIMED_HANDS: int = 300

var _rules: RuleSet = RuleSet.default_rules()
var _map: PackedByteArray = Ranks.identity_map()


func _random_counts(stream: RandomStream, size: int) -> PackedByteArray:
	var deck: PackedInt32Array = Deck.generate()
	var counts: PackedByteArray = PackedByteArray()
	counts.resize(Ranks.COUNT)
	for dealt: int in size:
		var pick: int = stream.next_int(dealt, deck.size() - 1)
		var card: int = deck[pick]
		deck[pick] = deck[dealt]
		deck[dealt] = card
		counts[CardInstance.from_deck_id(card).base_rank()] += 1
	return counts


func _decomposer(cap: int = CAP) -> HandDecomposer:
	return HandDecomposer.new(_rules, _map, cap)


func _used(decomposition: Decomposition) -> PackedByteArray:
	var used: PackedByteArray = PackedByteArray()
	used.resize(Ranks.COUNT)
	for group: Pattern in decomposition.groups:
		var counts: PackedByteArray = group.counts()
		for rank: int in Ranks.COUNT:
			used[rank] += counts[rank]
	return used


func _assert_is_legal(group: Pattern) -> void:
	var read: Classification = Classifier.classify(group.counts(), _rules, _map)
	assert_int(read.pattern.type).is_equal(group.type)


func test_matches_brute_force_on_random_hands() -> void:
	var stream: RandomStream = RandomStream.new(2201)
	var reference: HandReference = HandReference.new(_rules, _map)
	for _hand: int in LongRun.sample(150, 5000):
		var size: int = stream.next_int(1, 12)
		var counts: PackedByteArray = _random_counts(stream, size)
		var decomposer: HandDecomposer = _decomposer()
		var hands: int = HandDecomposer.hands_in(decomposer.score(counts))
		var label: String = "hand %s" % RankCounts.describe(counts)
		assert_int(hands).override_failure_message(label).is_equal(reference.fewest_plays(counts))
		var decomposition: Decomposition = decomposer.decompose(counts)
		assert_int(decomposition.hands()).override_failure_message(label).is_equal(hands)
		assert_array(Array(_used(decomposition))).is_equal(Array(counts))
		for group: Pattern in decomposition.groups:
			_assert_is_legal(group)


func test_the_memo_never_passes_its_cap() -> void:
	var stream: RandomStream = RandomStream.new(2202)
	var reference: HandDecomposer = _decomposer()
	for cap: int in [0, 8, 64]:
		var capped: HandDecomposer = _decomposer(cap)
		for _hand: int in 20:
			var counts: PackedByteArray = _random_counts(stream, 20)
			capped.clear()
			reference.clear()
			assert_int(capped.score(counts)).is_equal(reference.score(counts))
			assert_int(capped.memo_size()).is_less_equal(cap)


func test_the_median_for_twenty_cards_is_inside_budget() -> void:
	var stream: RandomStream = RandomStream.new(2203)
	var times: Array[int] = []
	var largest: int = 0
	var decomposer: HandDecomposer = _decomposer()
	for _hand: int in TIMED_HANDS:
		var counts: PackedByteArray = _random_counts(stream, 20)
		decomposer.clear()
		var started: int = Time.get_ticks_usec()
		decomposer.score(counts)
		times.append(Time.get_ticks_usec() - started)
		largest = maxi(largest, decomposer.memo_size())
	times.sort()
	var middle: int = times[times.size() >> 1]
	print("decompose median %d usec, slowest %d, memo peak %d" % [middle, times[-1], largest])
	assert_int(middle).is_less(MEDIAN_LIMIT_USEC)
	assert_int(largest).is_less_equal(CAP)
