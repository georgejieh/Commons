extends GdUnitTestSuite
## Rank constants, chainability and the index to label to index round trip.

const LABELS: PackedStringArray = [
	"3",
	"4",
	"5",
	"6",
	"7",
	"8",
	"9",
	"10",
	"J",
	"Q",
	"K",
	"A",
	"2",
	"Small Joker",
	"Big Joker",
]


func test_every_rank_round_trips_through_its_label() -> void:
	for rank: int in Ranks.COUNT:
		var label: String = tr(Ranks.label_key(rank))
		assert_str(label).is_equal(LABELS[rank])
		var key: String = Ranks.label_key(LABELS.find(label))
		assert_int(Ranks.from_label_key(key)).is_equal(rank)


func test_indices_follow_the_rank_order() -> void:
	assert_int(Ranks.THREE).is_equal(0)
	assert_int(Ranks.ACE).is_equal(11)
	assert_int(Ranks.TWO).is_equal(12)
	assert_int(Ranks.SMALL_JOKER).is_equal(13)
	assert_int(Ranks.BIG_JOKER).is_equal(14)


func test_only_three_to_ace_are_chainable() -> void:
	for rank: int in Ranks.COUNT:
		assert_bool(Ranks.is_chainable(rank)).is_equal(rank <= 11)
	assert_bool(Ranks.is_chainable(Ranks.INVALID)).is_false()


func test_unknown_key_is_invalid() -> void:
	assert_int(Ranks.from_label_key("rank.1")).is_equal(Ranks.INVALID)
	assert_bool(Ranks.is_valid(Ranks.INVALID)).is_false()
	assert_bool(Ranks.is_valid(Ranks.COUNT)).is_false()
