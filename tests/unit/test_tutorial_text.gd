extends GdUnitTestSuite
## The arrival's words in the string table are ADR 0026's, word for word: the Arrival
## page, what Wang says at every step and the line after it, the three one-time
## tooltips, and the two corrected lines. Read from the ADR itself, so a revision the
## table missed fails here. No slip holds more than two sentences.

const ADR: String = "res://docs/adr/0026-tutorial.md"
const TABLE: String = "res://data/strings/strings.csv"
const TIPS: Dictionary[String, String] = {
	"Private plot": "tip.plot", "Debuffs": "tip.debuffs", "Villager memory": "tip.memory"
}
const MOST_SENTENCES: int = 2


func _table() -> Dictionary[String, String]:
	var rows: Dictionary[String, String] = {}
	var file: FileAccess = FileAccess.open(TABLE, FileAccess.READ)
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() >= 2:
			rows[row[0]] = row[1]
	return rows


## The one quoted line in text, or "" when it quotes none.
func _quoted(text: String) -> String:
	var quote: RegExMatch = RegEx.create_from_string('"([^"]+)"').search(text)
	return "" if quote == null else quote.get_string(1)


func _expected() -> Dictionary[String, String]:
	var text: String = FileAccess.get_file_as_string(ADR).replace("\r", "")
	text = text.replace("’", "'").replace("‘", "'")
	var expected: Dictionary[String, String] = {}
	var arrival: RegEx = RegEx.create_from_string('(?m)^\\*\\*Arrival page\\.\\*\\* "(.+)"$')
	expected["tutorial.arrival.text"] = arrival.search(text).get_string(1)
	var step: RegEx = RegEx.create_from_string(
		"(?m)^\\| (\\d+) \\| ([^|]+?) \\| ([^|]+?) \\| ([^|]+?) \\|$"
	)
	for found: RegExMatch in step.search_all(text):
		var key: String = "tutorial.step.%02d." % int(found.get_string(1))
		expected[key + "say"] = _quoted(found.get_string(3))
		var then: String = _quoted(found.get_string(4))
		if not then.is_empty():
			expected[key + "then"] = then
	var tip: RegEx = RegEx.create_from_string('(?m)^\\| ([^|]+?) \\| [^|]+? \\| ("[^|]+") \\|$')
	for found: RegExMatch in tip.search_all(text):
		expected[TIPS[found.get_string(1)]] = _quoted(found.get_string(2))
	var fixed: RegEx = RegEx.create_from_string(
		'line becomes "([^"]+)", and the strip.s heading becomes "([^"]+)"'
	)
	var corrected: RegExMatch = fixed.search(text)
	expected["intro.ladder"] = corrected.get_string(1)
	expected["table.debuffs"] = corrected.get_string(2)
	return expected


func test_the_table_holds_the_adrs_text_word_for_word() -> void:
	assert_bool(FileAccess.file_exists(ADR)).override_failure_message(ADR).is_true()
	var expected: Dictionary[String, String] = _expected()
	# The page, twenty prompts, nineteen follow-ups, three tooltips, two corrections.
	assert_int(expected.size()).is_equal(1 + 20 + 19 + 3 + 2)
	var table: Dictionary[String, String] = _table()
	for key: String in expected:
		assert_str(table.get(key, "<missing>")).override_failure_message(key).is_equal(
			expected[key]
		)


func test_every_step_names_lines_the_table_holds() -> void:
	var table: Dictionary[String, String] = _table()
	for step: TutorialStep in RunTutorial.SCRIPT.steps:
		assert_bool(table.has(step.prompt_key)).override_failure_message(step.id).is_true()
		if not step.then_key.is_empty():
			assert_bool(table.has(step.then_key)).override_failure_message(step.id).is_true()
	for key: String in ["tutorial.begin", "tutorial.skip.confirm", "tip.got_it"]:
		assert_bool(table.has(key)).is_true()


func test_no_slip_holds_more_than_two_sentences() -> void:
	var ends: RegEx = RegEx.create_from_string("[.?!](\\s|$)")
	for key: String in _table():
		if not (key.begins_with("tutorial.step.") or key.begins_with("tip.")):
			continue
		var line: String = _table()[key]
		var sentences: int = ends.search_all(line).size()
		assert_int(sentences).override_failure_message(key).is_less_equal(MOST_SENTENCES)
