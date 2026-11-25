extends GdUnitTestSuite
## Rank labels and the range of a valid rank.

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


func test_every_rank_reads_as_its_label() -> void:
	for rank: int in Ranks.COUNT:
		assert_str(tr(Ranks.label_key(rank))).is_equal(LABELS[rank])


func test_only_the_fifteen_ranks_are_valid() -> void:
	assert_bool(Ranks.is_valid(Ranks.INVALID)).is_false()
	assert_bool(Ranks.is_valid(Ranks.COUNT)).is_false()
