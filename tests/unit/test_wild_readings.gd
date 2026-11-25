extends GdUnitTestSuite
## The readings and bomb tiers of ADR 0029, rules 2 to 6, on hands written out.

var _map: PackedByteArray = Ranks.identity_map()
var _sevens: RuleSet = WildReference.rules([Ranks.SEVEN] as Array[int], false)


func _readings(text: String, rules: RuleSet = _sevens) -> Array[Pattern]:
	return Readings.of(RankText.counts(text), rules, _map)


func _names(readings: Array[Pattern]) -> PackedStringArray:
	var names: PackedStringArray = []
	for reading: Pattern in readings:
		names.append(RankText.describe(reading))
	return names


## A bomb read from these printed cards as rank, which must be one of their readings.
func _bomb(text: String, rank: String, rules: RuleSet) -> Pattern:
	for reading: Pattern in _readings(text, rules):
		if reading.type == Pattern.Type.BOMB and reading.main_rank == RankText.rank(rank):
			return reading
	return null


func test_two_wild_sevens_alone_are_a_pair_of_sevens() -> void:
	assert_array(Array(_names(_readings("77")))).is_equal(["PAIR 7 x1 "])


func test_one_wild_seven_alone_is_a_seven() -> void:
	assert_array(Array(_names(_readings("7")))).is_equal(["SINGLE 7 x1 "])


func test_four_wild_sevens_are_first_the_pure_wild_bomb() -> void:
	var readings: Array[Pattern] = _readings("7777")
	assert_int(readings[0].type).is_equal(Pattern.Type.BOMB)
	assert_int(readings[0].main_rank).is_equal(Ranks.SEVEN)
	assert_int(PlayComparator.bomb_kind(readings[0])).is_equal(PlayComparator.PURE_WILD)
	for reading: Pattern in readings:
		assert_bool(reading.counts()[Ranks.SEVEN] > 0).is_true()


func test_three_nines_and_a_wild_are_a_soft_bomb_and_a_trio_with_a_single() -> void:
	var names: PackedStringArray = _names(_readings("9997"))
	assert_array(Array(names)).is_equal(["BOMB 9 x1 ", "TRIO_SINGLE 9 x1 7"])
	var bomb: Pattern = _readings("9997")[0]
	assert_int(PlayComparator.bomb_kind(bomb)).is_equal(PlayComparator.SOFT)
	assert_int(bomb.stand_ins()).is_equal(1)
	assert_array(Array(bomb.spent_counts())).is_equal(Array(RankText.counts("9997")))


func test_a_wild_card_at_its_own_rank_is_no_stand_in() -> void:
	var readings: Array[Pattern] = _readings("45687")
	assert_array(Array(_names(readings))).is_equal(["STRAIGHT 4 x5 "])
	assert_int(readings[0].stand_ins()).is_equal(0)
	assert_bool(readings[0].spent.is_empty()).is_true()


func test_a_wild_card_completes_a_straight() -> void:
	var jacks: RuleSet = WildReference.rules([Ranks.JACK] as Array[int], false)
	for text: String in ["3456J", "3467J"]:
		var readings: Array[Pattern] = _readings(text, jacks)
		assert_array(Array(_names(readings))).is_equal(["STRAIGHT 3 x5 "])
		assert_int(readings[0].stand_ins()).is_equal(1)
		assert_int(readings[0].spent_counts()[Ranks.JACK]).is_equal(1)
		assert_int(readings[0].counts()[Ranks.JACK]).is_equal(0)


func test_a_wild_card_never_stands_in_for_a_joker() -> void:
	assert_array(_readings("s7")).is_empty()
	for reading: Pattern in _readings("sb77"):
		assert_int(reading.counts()[Ranks.BIG_JOKER]).is_equal(1)
		assert_int(reading.counts()[Ranks.SMALL_JOKER]).is_equal(1)


func test_a_play_of_wild_cards_alone_keeps_one_at_its_own_rank() -> void:
	var two: RuleSet = WildReference.rules([Ranks.SEVEN, Ranks.QUEEN] as Array[int], false)
	for reading: Pattern in _readings("7QQ", two):
		var counts: PackedByteArray = reading.counts()
		assert_bool(counts[Ranks.SEVEN] > 0 or counts[Ranks.QUEEN] > 0).is_true()
	assert_array(Array(_names(_readings("7Q", two)))).is_equal(["PAIR Q x1 ", "PAIR 7 x1 "])


func test_bombs_order_by_rule_five() -> void:
	var rocket: Pattern = _readings("sb")[0]
	var pure: Pattern = _bomb("7777", "7", _sevens)
	var high_natural: Pattern = _bomb("2222", "2", _sevens)
	var low_natural: Pattern = _bomb("3333", "3", _sevens)
	var high_soft: Pattern = _bomb("2227", "2", _sevens)
	var low_soft: Pattern = _bomb("3337", "3", _sevens)
	var order: Array[Pattern] = [rocket, pure, high_natural, low_natural, high_soft, low_soft]
	for high: int in order.size():
		for low: int in order.size():
			var expected: bool = high < low
			assert_bool(PlayComparator.beats(order[high], order[low], _sevens)).is_equal(expected)


func test_a_pure_wild_bomb_may_sit_above_the_rocket() -> void:
	var rules: RuleSet = WildReference.rules([Ranks.SEVEN] as Array[int], false, false)
	var rocket: Pattern = _readings("sb", rules)[0]
	var pure: Pattern = _bomb("7777", "7", rules)
	var natural: Pattern = _bomb("2222", "2", rules)
	assert_bool(PlayComparator.beats(pure, rocket, rules)).is_true()
	assert_bool(PlayComparator.beats(rocket, natural, rules)).is_true()
	assert_bool(PlayComparator.beats(natural, pure, rules)).is_false()


func test_bigger_bombs_beat_smaller_whatever_the_kind() -> void:
	var rules: RuleSet = WildReference.rules([Ranks.SEVEN] as Array[int], true)
	var rocket: Pattern = _readings("sb", rules)[0]
	var pure: Pattern = _bomb("7777", "7", rules)
	var five_soft: Pattern = _bomb("33337", "3", rules)
	var five_natural: Pattern = _bomb("33333", "3", rules)
	var six_soft: Pattern = _bomb("444477", "4", rules)
	assert_bool(PlayComparator.beats(five_soft, pure, rules)).is_true()
	assert_bool(PlayComparator.beats(five_natural, five_soft, rules)).is_true()
	assert_bool(PlayComparator.beats(six_soft, five_natural, rules)).is_true()
	assert_bool(PlayComparator.beats(rocket, six_soft, rules)).is_true()
	assert_bool(PlayComparator.beats(six_soft, rocket, rules)).is_false()


func test_a_reading_is_ranked_by_the_rank_it_stands_for() -> void:
	var map: PackedByteArray = Ranks.identity_map()
	ReversedRanks.reverse(map)
	var readings: Array[Pattern] = Readings.of(RankText.counts("JJ7"), _sevens, map)
	var trio: Pattern = null
	for reading: Pattern in readings:
		if reading.type == Pattern.Type.TRIO:
			trio = reading
	assert_int(trio.main_rank).is_equal(Ranks.JACK)
	assert_int(trio.key & 0xFF).is_equal(map[Ranks.JACK])


func test_a_named_reading_is_checked_against_the_cards() -> void:
	var counts: PackedByteArray = RankText.counts("9997")
	var trio: Pattern = _readings("9997")[1]
	var kicker_queen: Pattern = Pattern.new(
		Pattern.Type.TRIO_SINGLE, Ranks.NINE, 1, 4, PackedByteArray([Ranks.QUEEN]), Ranks.NINE
	)
	var pair: Pattern = _readings("99")[0]
	assert_object(Readings.checked(trio, counts, _sevens, _map)).is_not_null()
	assert_object(Readings.checked(kicker_queen, counts, _sevens, _map)).is_not_null()
	assert_object(Readings.checked(pair, counts, _sevens, _map)).is_null()
	assert_object(Readings.checked(trio, RankText.counts("9998"), _sevens, _map)).is_null()
