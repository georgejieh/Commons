extends GdUnitTestSuite
## The endings' text in the string table is ADR 0024's, word for word: every ending's
## title and text, both deaths' text, every epilogue line, the two state lines, the dead
## families' line and the historical note. Read from the ADR itself, so a revision of its
## text that the table missed fails here. Apostrophes are straight in the table.

const ADR: String = "res://docs/adr/0024-endings.md"
const TABLE: String = "res://data/strings/strings.csv"


func _table() -> Dictionary[String, String]:
	var rows: Dictionary[String, String] = {}
	var file: FileAccess = FileAccess.open(TABLE, FileAccess.READ)
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() >= 2:
			rows[row[0]] = row[1]
	return rows


func _section(text: String, from: String, to: String) -> String:
	var start: int = text.find(from)
	return text.substr(start, text.find(to, start) - start)


## What the ADR says each key holds.
func _expected() -> Dictionary[String, String]:
	var text: String = FileAccess.get_file_as_string(ADR).replace("\r", "")
	text = text.replace("’", "'").replace("‘", "'")
	var ids: Dictionary[String, String] = {}
	var rule: RegEx = RegEx.create_from_string("(?m)^\\| ([^|]+?) \\| `([a-z_]+)` \\|")
	for found: RegExMatch in rule.search_all(text):
		ids[found.get_string(1)] = found.get_string(2)
	var expected: Dictionary[String, String] = {}
	var bold: RegEx = RegEx.create_from_string("(?m)^\\*\\*(.+?)\\.\\*\\* (.+)$")
	for found: RegExMatch in bold.search_all(_section(text, "### Endings", "### Deaths")):
		var ending_id: String = ids[found.get_string(1)]
		expected["ending.%s.title" % ending_id] = found.get_string(1)
		expected["ending.%s.text" % ending_id] = found.get_string(2)
	for found: RegExMatch in bold.search_all(_section(text, "### Deaths", "### Epilogue")):
		expected["death.%s.text" % found.get_string(1).to_lower()] = found.get_string(2)
	var lines: String = _section(text, "### Epilogue lines", "### The historical note")
	var row: RegEx = RegEx.create_from_string(
		"(?m)^\\| ([^|]+?) \\| ([^|]+?) \\| ([^|]+?) \\| ([^|]+?) \\|$"
	)
	for found: RegExMatch in row.search_all(lines):
		if not ids.has(found.get_string(1)):
			continue
		for index: int in Endings.DISPOSITIONS.size():
			var key: String = Endings.line_key(
				ids[found.get_string(1)], Endings.DISPOSITIONS[index]
			)
			expected[key] = found.get_string(index + 2)
	var bullets: Dictionary[String, String] = {}
	var bullet: RegEx = RegEx.create_from_string("(?m)^- ([^:]+): (.+)$")
	for found: RegExMatch in bullet.search_all(lines):
		bullets[found.get_string(1)] = found.get_string(2)
	expected[Endings.REEDUCATION_KEY] = bullets["In reeducation"]
	expected[Endings.DEPOSED_KEY] = bullets["Deposed"]
	expected[Endings.MISSING_KEY] = bullets["The dead, on Lean Years and Full Granary"]
	var note: RegEx = RegEx.create_from_string("(?m)^> (.+)$")
	var noted: String = _section(text, "### The historical note", "## Consequences")
	expected[Endings.NOTE_KEY] = note.search(noted).get_string(1)
	return expected


func test_the_table_holds_the_adrs_text_word_for_word() -> void:
	if not FileAccess.file_exists(ADR):
		return
	var expected: Dictionary[String, String] = _expected()
	# Every key but the deaths' titles, which the ADR leaves to the build.
	assert_int(expected.size()).is_equal(Endings.keys().size() - 2)
	var table: Dictionary[String, String] = _table()
	for key: String in expected:
		assert_str(table.get(key, "<missing>")).override_failure_message(key).is_equal(
			expected[key]
		)


func test_the_table_uses_straight_apostrophes() -> void:
	var table: Dictionary[String, String] = _table()
	for key: String in Endings.keys():
		assert_bool(table[key].contains("’")).override_failure_message(key).is_false()
