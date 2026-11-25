extends GdUnitTestSuite
## The text scans of P5.1 and ADR 0034, over every script, scene and resource in core/,
## game/, ui/ and data/: no hard-coded player-facing text, every key used is in the
## table, the table and the game are English only, and every font size in ui/ comes from
## TextSize. SourceScan says how a literal is known to reach the player, and SizeScan how
## a size is known to come from TextSize. Each failure names the file and line.

const SOURCE: Array[String] = ["gd", "tscn", "tres"]
## The one allow list, by check and path (a folder covers everything under it), each
## with its reason.
const ALLOWED: Dictionary[String, String] = {
	"text res://core/modifiers/modifier_validator.gd":
	"Validation reports for tests and the content checks, never shown in play.",
	"text res://core/run/scripted_villager.gd":
	"The arrival's scripted seats report a fault through push_error, for tests.",
	"text res://game/file/file_watch.gd":
	"LOG_LINE marks a detector's line in the log, which tools/test.sh looks for.",
	"text res://game/session/game_log.gd": "The game's lines in its log file, never shown in play.",
	"text res://data/villagers/names.tres":
	"The name generator's pools and the names it must never make: proper names.",
	"cjk res://data/run/endings.tres": "Each ending's seal, drawn as decoration by HanziSeal.",
	"cjk res://data/villagers/families/": "Each family's hanzi, decoration only (FamilyDef).",
	"sizes res://ui/cards/card_view.gd": "Rank glyphs and joker words are card art.",
	"sizes res://ui/cards/card_view.tscn": "The Rank glyph's size is card art.",
	"sizes res://ui/screens/rank_chip.gd": "A rank glyph on a chip is art.",
	"sizes res://ui/screens/hanzi_seal.gd": "A seal is art.",
	"sizes res://ui/screens/ink_seal.gd": "A seal is art.",
	"sizes res://ui/screens/file_stamp.gd": "A stamp is art.",
	"sizes res://ui/screens/scarce_stamp.gd": "A stamp is art.",
	"sizes res://ui/table2d/confiscated_mark.gd":
	"A stamp is art; on a small card it shrinks no further than TextSize.least.",
	"sizes res://ui/screens/name_fit.gd":
	"Sets the sizes its callers took from TextSize; every NameFit call is scanned.",
	"sizes res://ui/theme/commons_theme.tres":
	"The project's fallback theme at Standard; DemoApp sets its size from TextSize.",
}


func test_no_hard_coded_player_facing_text() -> void:
	var keys: Dictionary[String, bool] = SourceScan.table_keys()
	var offences: PackedStringArray = []
	for path: String in SourceScan.files(SourceScan.ROOTS, SOURCE):
		if not _allowed("text", path):
			offences.append_array(SourceScan.text_offences(path, SourceScan.read(path), keys))
	assert_array(offences).override_failure_message("\n".join(offences)).is_empty()


## Every literal key handed to tr, TranslationServer.translate or Strings is in the
## table, and every key built at run time starts or is shaped like at least one key.
func test_every_key_used_is_in_the_table() -> void:
	var keys: Dictionary[String, bool] = SourceScan.table_keys()
	var offences: PackedStringArray = []
	for path: String in SourceScan.files(SourceScan.ROOTS, ["gd"]):
		offences.append_array(SourceScan.key_offences(path, SourceScan.read(path), keys))
	assert_array(offences).override_failure_message("\n".join(offences)).is_empty()


func test_the_table_has_one_language_and_it_is_english() -> void:
	var rows: Array[PackedStringArray] = SourceScan.table_rows()
	assert_array(Array(rows[0])).is_equal(["keys", "en"])
	var offences: PackedStringArray = []
	for index: int in rows.size():
		var row: PackedStringArray = rows[index]
		if row.size() != 2:
			offences.append("row %d has %d columns" % [index + 1, row.size()])
		elif not SourceScan.cjk_lines(row[0], row[1]).is_empty():
			offences.append("%s holds a CJK character" % row[0])
	assert_array(offences).override_failure_message("\n".join(offences)).is_empty()


## Chinese characters are decoration: they appear only in the data the seals draw, and
## every file on the allow list still holds some, so the list stays honest.
func test_chinese_characters_appear_only_where_decoration_is_drawn() -> void:
	var offences: PackedStringArray = []
	var holding: Dictionary[String, bool] = {}
	var kinds: Array[String] = SOURCE.duplicate()
	kinds.append_array(["csv", "json", "cfg"])
	for path: String in SourceScan.files(SourceScan.ROOTS, kinds):
		if SourceScan.cjk_lines(path, SourceScan.read(path)).is_empty():
			continue
		holding[_entry("cjk", path)] = true
		if not _allowed("cjk", path):
			offences.append_array(SourceScan.cjk_lines(path, SourceScan.read(path)))
	assert_array(offences).override_failure_message("\n".join(offences)).is_empty()
	for entry: String in ALLOWED:
		if entry.begins_with("cjk "):
			assert_bool(holding.has(entry)).override_failure_message(entry).is_true()


func test_every_font_size_in_ui_comes_from_text_size() -> void:
	var offences: PackedStringArray = []
	for path: String in SourceScan.files(["res://ui"], SOURCE):
		if not _allowed("sizes", path):
			offences.append_array(SizeScan.offences(path, SourceScan.read(path)))
	assert_array(offences).override_failure_message("\n".join(offences)).is_empty()


## The scans catch what they are for: one made-up offence of each kind, and none in
## the developer text and keys beside them.
func test_the_text_scan_catches_each_kind_of_hard_coded_text() -> void:
	var keys: Dictionary[String, bool] = SourceScan.table_keys()
	var script: String = (
		"\n"
		. join(
			[
				'label.text = "Hello"',
				'tip.tooltip_text = "Click here"',
				'field.placeholder_text = "Name"',
				'window.title = "Options"',
				'draw_string(font, at, "Score", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)',
				'tag.draw_multiline_string(font, at, "Wide", HORIZONTAL_ALIGNMENT_LEFT, 80, 20)',
				'rich.append_text("Bold")',
				'rich.add_text("Plain")',
				'var made: Label = ScreenKit.label("Welcome", 24)',
				'ScreenKit.button("Go")',
				'ScreenKit.header("Eyebrow", tr("title.new_run"))',
				'ScreenKit.styled("Styled", CommonsTheme.TITLE)',
				'ScreenKit.eyebrow("Small")',
				'var line: String = "The landlord wins"',
			]
		)
	)
	var quiet: String = (
		"\n"
		. join(
			[
				'push_error("Something went wrong here")',
				'assert(ok, "Must hold before the round")',
				'label.text = tr("title.new_run")',
				'label.text = "%s %d" % [name, count]',
				'line.text = tr("intro.seated").format({"names": names})',
				'rich.append_text("[b]%s[/b]" % name)',
				'node.name = "Rank"',
				'var words: Dictionary = {"two words": 1}',
				'title = controller.envelope_card_text(kind, "name", card)',
				'label.text = "settings.text_size"',
				'# A comment with "Several words" in it',
			]
		)
	)
	var caught: PackedStringArray = SourceScan.text_offences("res://made_up.gd", script, keys)
	assert_array(caught).override_failure_message("\n".join(caught)).has_size(14)
	var missed: PackedStringArray = SourceScan.text_offences("res://made_up.gd", quiet, keys)
	assert_array(missed).override_failure_message("\n".join(missed)).is_empty()
	var scene: String = 'text = "Start game"\ntooltip_text = "Hover"\ntext = "card.rank_as"'
	assert_int(SourceScan.text_offences("res://made_up.tscn", scene, keys).size()).is_equal(2)


func test_the_key_scan_catches_a_missing_key() -> void:
	var keys: Dictionary[String, bool] = SourceScan.table_keys()
	var bad: String = (
		"\n"
		. join(
			[
				'tr("no.such.key")',
				'TranslationServer.translate("no.such.key")',
				'Strings.count("no.such.count", 2)',
				'tr("nosuch." + key)',
				'tr("modifier.%s.nope" % id)',
			]
		)
	)
	var good: String = (
		"\n"
		. join(
			[
				'tr("title.new_run")',
				'tr("settings." + key)',
				'tr("modifier.%s.name" % id)',
				"tr(key)",
				'Strings.format("intro.seated", {"names": names})',
			]
		)
	)
	assert_int(SourceScan.key_offences("res://made_up.gd", bad, keys).size()).is_equal(5)
	var missed: PackedStringArray = SourceScan.key_offences("res://made_up.gd", good, keys)
	assert_array(missed).override_failure_message("\n".join(missed)).is_empty()


func test_the_language_scan_catches_a_chinese_character() -> void:
	var text: String = 'var seal: String = "斗"\nvar word: String = "fight"'
	assert_array(Array(SourceScan.cjk_lines("res://made_up.gd", text))).is_equal(
		["res://made_up.gd:1"]
	)


func test_the_size_scan_catches_a_size_set_any_other_way() -> void:
	var bad: String = (
		"\n"
		. join(
			[
				'label.add_theme_font_size_override("font_size", 20)',
				"draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)",
				'theme.set_font_size("font_size", "Label", 20)',
				"theme.default_font_size = 22",
				'var line: String = "[font_size=%d]x[/font_size]" % 14',
				"NameFit.apply(label, text, 80.0, 20, 16)",
			]
		)
	)
	var good: String = (
		"\n"
		. join(
			[
				"func _draw() -> void:",
				"\tvar px: int = TextSize.px(20)",
				"\tdraw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ink)",
				'\tlabel.add_theme_font_size_override("font_size", TextSize.px(20))',
				"\tNameFit.apply(label, text, 80.0, TextSize.px(20), TextSize.least(16))",
			]
		)
	)
	var caught: PackedStringArray = SizeScan.offences("res://ui/made_up.gd", bad)
	assert_array(caught).override_failure_message("\n".join(caught)).has_size(6)
	var missed: PackedStringArray = SizeScan.offences("res://ui/made_up.gd", good)
	assert_array(missed).override_failure_message("\n".join(missed)).is_empty()
	var scene: String = "theme_override_font_sizes/font_size = 18"
	assert_int(SizeScan.offences("res://ui/made_up.tscn", scene).size()).is_equal(1)


func _entry(check: String, path: String) -> String:
	for entry: String in ALLOWED:
		if entry.begins_with(check + " ") and path.begins_with(entry.trim_prefix(check + " ")):
			return entry
	return check + " " + path


func _allowed(check: String, path: String) -> bool:
	return ALLOWED.has(_entry(check, path))
