extends GdUnitTestSuite
## Five to eight natural copies of a rank in one hand, as an exchanged deck allows (ADR
## 0042), read by the rule a fifth copy from the plot already reads by (ADR 0029): without
## five_plus_is_bomb, four of them are a Bomb and more are no single play; with it, all of
## them are one Bomb, larger as it holds more. The move generator, the hand decomposer and
## the count key hold them whole.

const MOST: int = 8


func _rules(big_bombs: bool) -> RuleSet:
	var params: RuleParams = RuleSet.DEFAULT_PARAMS.copy()
	params.five_plus_is_bomb = big_bombs
	return RuleSet.new(params)


func _nines(count: int) -> PackedByteArray:
	var counts: PackedByteArray = PackedByteArray()
	counts.resize(Ranks.COUNT)
	counts[Ranks.NINE] = count
	return counts


func test_five_to_eight_copies_read_as_one_bomb_only_with_big_bombs() -> void:
	for count: int in range(5, MOST + 1):
		for big: bool in [false, true]:
			var reading: Classification = Classifier.classify(
				_nines(count), _rules(big), Ranks.identity_map()
			)
			var case: String = "%d nines, big bombs %s" % [count, big]
			assert_bool(reading.is_valid()).override_failure_message(case).is_equal(big)
			if big:
				assert_int(reading.pattern.type).is_equal(Pattern.Type.BOMB)
				assert_int(reading.pattern.card_count).is_equal(count)


func test_a_larger_big_bomb_beats_a_smaller_one() -> void:
	var rules: RuleSet = _rules(true)
	var map: PackedByteArray = Ranks.identity_map()
	for count: int in range(5, MOST + 1):
		var bigger: Pattern = Classifier.classify(_nines(count), rules, map).pattern
		var smaller: Pattern = Classifier.classify(_nines(count - 1), rules, map).pattern
		assert_bool(PlayComparator.beats(bigger, smaller, rules)).is_true()
		assert_bool(PlayComparator.beats(smaller, bigger, rules)).is_false()


func test_eight_copies_lead_every_bomb_size_the_rules_allow() -> void:
	var counts: PackedByteArray = _nines(MOST)
	var mask: int = 1 << Ranks.NINE
	for big: bool in [false, true]:
		var sizes: Array[int] = []
		for move: Pattern in MoveGenerator.generate(
			counts, mask, null, _rules(big), Ranks.identity_map()
		):
			if move.type == Pattern.Type.BOMB:
				sizes.append(move.card_count)
		sizes.sort()
		assert_array(sizes).is_equal([4, 5, 6, 7, 8] if big else [4])


func test_eight_copies_decompose_into_two_bombs_or_one() -> void:
	for big: bool in [false, true]:
		var decomposer: HandDecomposer = HandDecomposer.new(
			_rules(big), Ranks.identity_map(), BotConfig.DEFAULT_WEIGHTS.memo_cap
		)
		var groups: Array[Pattern] = decomposer.decompose(_nines(MOST)).groups
		var cards: int = 0
		for group: Pattern in groups:
			assert_int(group.type).is_equal(Pattern.Type.BOMB)
			cards += group.card_count
		assert_int(groups.size()).is_equal(1 if big else 2)
		assert_int(cards).is_equal(MOST)


func test_a_count_key_holds_every_count_up_to_its_most() -> void:
	var counts: PackedByteArray = PackedByteArray()
	counts.resize(Ranks.COUNT)
	for rank: int in Ranks.COUNT:
		counts[rank] = rank % (CountKey.MAX_COUNT + 1)
	counts[Ranks.NINE] = CountKey.MAX_COUNT
	assert_that(CountKey.decode(CountKey.encode(counts))).is_equal(counts)
