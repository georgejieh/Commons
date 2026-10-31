extends GdUnitTestSuite
## Every hand type at level 1, with and without each base multiplier.
## Set UPDATE_GOLDEN=1 to rewrite the golden file after an intended change.

const GOLDEN_PATH: String = "res://tests/golden/scoring.golden"
const HANDS: Array[String] = [
	"9",
	"99",
	"999",
	"9993",
	"99933",
	"34567",
	"334455",
	"333444",
	"33344456",
	"3334445566",
	"999945",
	"99994455",
	"9999",
	"sb",
]


func _lines() -> String:
	var rules: RuleSet = RuleSet.default_rules()
	var map: PackedByteArray = Ranks.identity_map()
	var stack: ModifierStack = ModifierStack.new()
	var lines: PackedStringArray = []
	for text: String in HANDS:
		var pattern: Pattern = Classifier.classify(RankText.counts(text), rules, map).pattern
		var cards: Array[CardInstance] = RoundScript.stacked_deal([text], "").hands[0].cards()
		var score: ScoreBreakdown = Scorer.score_play(cards, pattern, 1, 0, false, stack)
		var name: String = Pattern.Type.keys()[pattern.type]
		lines.append("%s grain=%s zeal=%s total=%s" % [name, score.grain, score.zeal, score.total])
		for finish: int in RoundEvent.Finish.values():
			for first: bool in [false, true]:
				var multiplier: float = Scorer.round_multiplier(finish, first, true, rules)
				var finish_name: String = RoundEvent.Finish.keys()[finish]
				lines.append(
					(
						"  %s first=%s total=%s"
						% [finish_name, first, Scorer.round_total(score.total, multiplier)]
					)
				)
	return "\n".join(lines) + "\n"


func test_every_hand_type_covers_every_multiplier() -> void:
	var text: String = _lines()
	if OS.get_environment("UPDATE_GOLDEN") == "1":
		var file: FileAccess = FileAccess.open(GOLDEN_PATH, FileAccess.WRITE)
		file.store_string(text)
		file.close()
	var golden: String = FileAccess.get_file_as_string(GOLDEN_PATH)
	assert_str(golden.replace("\r", "")).is_equal(text)
	for type: int in range(Pattern.Type.SINGLE, Pattern.Type.size()):
		assert_str(text).contains(Pattern.Type.keys()[type] + " grain=")
