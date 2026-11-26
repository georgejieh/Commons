extends GdUnitTestSuite
## What the family's file leaves on screen (ADR 0022, P4.19): the title's stamp, only
## with an entry and clear of every button and the title; the file's page in the
## history, oldest first, absent with no entry; villagers' lines about the work team's
## visit, only in a run that began with an entry; and the stage past the last, reached
## only with an entry at the last stage, where the screens read as successes and the
## small ledger keeps the true figures at the table and in both shops, all of it inside
## the screen.

const SEED: int = 7217
const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 800)]
const SLACK: float = 1.5
const FAMINE: int = 83
const VISIT: WorkTeamTalk = preload("res://data/ui/work_team_talk.tres")
## Lines a seat is asked for in the villagers' test: enough that a 4% chance shows.
const SAID: int = 600

var _app: DemoApp
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)


func after_test() -> void:
	get_tree().root.size = _was_size
	Saves.run_service().delete()
	Saves.profile_service().delete()
	ArtStages.stage_override = -1
	ArtStages.latch_value(0.0)


func _loop() -> RunLoop:
	return _app.controller.run_loop()


static func _entry(key: String, year: int, quota: int, figures: Dictionary) -> FileEntry:
	var entry: FileEntry = FileEntry.new()
	entry.detector = FileEntry.SEAL if figures.is_empty() else FileEntry.BOOK
	entry.run_id = "1-2"
	entry.generation = 2
	entry.year = year
	entry.quota = quota
	for figure: String in figures:
		entry.figures[figure] = float(figures[figure])
	entry.key = key
	return entry


func _file(count: int, corruption: float = 0.0) -> Array[FileEntry]:
	var data: ProfileData = ProfileData.new()
	data.corruption = corruption
	data.file.append(_entry("a", 3, 7, {"coupons": 120.0, "famine": 5.0}))
	if count > 1:
		data.file.append(_entry("b", 4, 9, {}))
	Profile.write(Saves.profile_service(), data)
	return data.file


func test_the_stamp_shows_only_with_an_entry_clear_of_the_buttons() -> void:
	var title: TitleScreen = _app.show_screen("title", true)
	await await_idle_frame()
	assert_object(title.stamp()).is_null()
	_file(2)
	for screen_size: Vector2i in SIZES:
		get_tree().root.size = screen_size
		title = _app.show_screen("title", true)
		await await_idle_frame()
		await await_idle_frame()
		var stamp: FileStamp = title.stamp()
		assert_object(stamp).is_not_null()
		assert_array(Array(stamp.words())).contains(["2 ENTRIES"])
		var area: Rect2 = stamp.get_global_rect()
		var screen: Rect2 = get_tree().root.get_visible_rect().grow(SLACK)
		assert_bool(screen.encloses(area)).is_true()
		assert_int(stamp.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
		for node: Node in title.find_children("*", "Control", true, false):
			var control: Control = node as Control
			var titled: bool = control is TitleWord
			if not control.is_visible_in_tree() or not (control is Button or titled):
				continue
			var where: String = "%s covers %s" % [screen_size, control.get_path()]
			var clear: bool = not area.intersects(control.get_global_rect())
			assert_bool(clear).override_failure_message(where).is_true()


func test_the_history_lists_the_file_oldest_first_and_only_with_an_entry() -> void:
	var page: VillageHistoryScreen = _app.show_screen("village_history", true)
	await await_idle_frame()
	assert_array(Array(page.file_lines())).is_empty()
	var entries: Array[FileEntry] = _file(2)
	page = _app.show_screen("village_history", true)
	await await_idle_frame()
	var lines: PackedStringArray = page.file_lines()
	assert_int(lines.size()).is_equal(3)
	assert_str(lines[0]).is_equal(HistoryView.file_line(entries[0]))
	assert_str(lines[0]).contains("Year 3, Quota 2").contains("coupons and Famine")
	assert_str(lines[1]).is_equal(HistoryView.file_line(entries[1]))
	assert_str(lines[1]).contains(tr("hist.file.seal"))
	assert_str(lines[2]).is_equal(tr("hist.file.kept"))


## Lines said for a seat over many passes, counting the work team's.
func _visit_lines(entries: int) -> int:
	_app.new_run(SEED)
	_loop().state.identity.file_entries = entries
	_app.controller.reseal_book()
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	var speech: TableSpeech = table.get("_speech")
	var visits: Array[int] = [0]
	speech.spoke.connect(
		func(_seat: int, _event: String, line: SpeechLine) -> void:
			if line.text_key.begins_with("speech.visit."):
				visits[0] += 1
	)
	speech.hurrying = true
	for _said: int in SAID:
		speech.say(1, VISIT.event)
	speech.hurrying = false
	return visits[0]


func test_villagers_speak_of_the_visit_only_after_an_entry() -> void:
	assert_int(await _visit_lines(0)).is_equal(0)
	assert_object(TableSpeech.visit_stream(_app.controller)).is_null()
	assert_int(await _visit_lines(1)).is_greater(0)
	assert_object(TableSpeech.visit_stream(_app.controller)).is_not_null()
	assert_int(VISIT.lines.size()).is_between(8, 12)
	assert_array(SpeechBook.EVENTS).contains([VISIT.event])
	for line: SpeechLine in VISIT.lines:
		assert_bool(VoiceScript.DEFAULT.moods.has(line.mood)).is_true()
		assert_str(tr(line.text_key)).is_not_equal(line.text_key)


func test_the_stage_past_the_last_needs_an_entry_at_the_last_stage() -> void:
	ArtStages.latch_value(95.0)
	assert_int(ArtStages.stage()).is_equal(ArtStages.LAST_STAGE)
	ArtStages.latch_value(55.0, true)
	assert_int(ArtStages.stage()).is_equal(5)
	ArtStages.latch_value(95.0, true)
	assert_int(ArtStages.stage()).is_equal(ArtStages.FILED_STAGE)
	assert_bool(ArtStages.past_last()).is_true()
	ArtStages.latch_value(0.0)
	var value: PackedStringArray = ["--corruption", "100"]
	var stage: PackedStringArray = ["--corruption-stage", "10"]
	assert_int(ArtStages.stage_from(true, value, 0)).is_equal(ArtStages.LAST_STAGE)
	assert_int(ArtStages.stage_from(true, stage, 0)).is_equal(ArtStages.FILED_STAGE)
	_file(1, 95.0)
	ArtStages.latch(Saves.profile_service())
	assert_int(ArtStages.stage()).is_equal(ArtStages.FILED_STAGE)
	# The art falls back to the last stage's, and the wear stays at its most.
	ArtStages.intensity_override = 1.0
	var title: Texture2D = ScreenKit.ART.title
	var last: Texture2D = ArtStages.resolve(title, ArtStages.LAST_STAGE)
	assert_object(ArtStages.resolve(title)).is_same(last)
	assert_float(BowlGrime.wear()).is_equal(1.0)
	ArtStages.intensity_override = -1.0


## The run's figures where no other number on the page is.
func _figures() -> void:
	var state: RunState = _loop().state
	state.famine = FAMINE
	state.coupons = 37
	_app.controller.reseal_book()


func test_at_the_stage_past_the_last_the_table_reads_as_success() -> void:
	_app.new_run(SEED)
	_figures()
	ArtStages.stage_override = ArtStages.FILED_STAGE
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	await await_idle_frame()
	var hud: TableHud = table.get("_hud")
	assert_str(hud.quota.text()).is_equal(tr(ShownFigures.FULFILLED))
	assert_bool(hud.famine.visible).is_false()
	assert_bool(hud.denunciation.visible).is_false()
	assert_str(hud.coupons.text).is_equal(tr(ShownFigures.AMPLE))
	var ledger: Ledger = table.get("_ledger")
	assert_bool(ledger.books.is_visible_in_tree()).is_true()
	var slip: String = " ".join(ledger.books.texts())
	assert_str(slip).contains("Famine %d" % FAMINE).contains("Coupons 37")
	assert_int(int(hud.get_combined_minimum_size().x)).is_less_equal(1920)
	var books: Rect2 = ledger.books.get_global_rect()
	var plays: Control = ledger.get("_plays")
	assert_bool(books.intersects(plays.get_global_rect())).is_false()
	var paper: Control = ledger.get_parent()
	assert_bool(paper.get_global_rect().grow(SLACK).encloses(books)).is_true()
	# The same run at stage 9 shows its figures as they are, and no slip.
	ArtStages.stage_override = ArtStages.LAST_STAGE
	table = _app.show_screen("table", true)
	await await_idle_frame()
	ledger = table.get("_ledger")
	assert_bool(ledger.books.visible).is_false()
	hud = table.get("_hud")
	assert_str(hud.coupons.text).is_equal(Strings.count("table.coupons", 37))


func test_at_the_stage_past_the_last_both_shops_keep_the_small_ledger() -> void:
	_app.new_run(SEED)
	var driver: ControllerScript = ControllerScript.new()
	driver.play_to(self, _app.controller, RunController.AWAIT_SET_OVER)
	_app.controller.finish_set()
	_figures()
	ArtStages.stage_override = ArtStages.FILED_STAGE
	for screen_size: Vector2i in SIZES:
		get_tree().root.size = screen_size
		for screen_id: String in ["store", "black_market"]:
			var shop: StoreScreen = _app.show_screen(screen_id, true)
			await await_idle_frame()
			await await_idle_frame()
			var where: String = "%s %s" % [screen_id, screen_size]
			var books: SmallLedger = shop.get("_books")
			assert_bool(books.is_visible_in_tree()).override_failure_message(where).is_true()
			assert_str(" ".join(books.texts())).contains("Coupons 37").contains("Famine 83")
			var coupons: Label = shop.get("_coupons")
			assert_str(coupons.text).is_equal(tr(ShownFigures.AMPLE))
			_check_blocks(shop, books, where)


## Every block of the page and the slip lie inside the screen and apart.
func _check_blocks(shop: StoreScreen, books: Control, where: String) -> void:
	var screen: Rect2 = get_tree().root.get_visible_rect().grow(SLACK)
	var rects: Dictionary[String, Rect2] = {}
	for name: String in shop.blocks():
		rects[name] = shop.blocks()[name].get_global_rect()
	assert_bool(screen.encloses(books.get_global_rect())).override_failure_message(where).is_true()
	var names: Array[String] = rects.keys()
	for first: int in names.size():
		var a: Rect2 = rects[names[first]].grow(-SLACK)
		assert_bool(screen.encloses(rects[names[first]])).override_failure_message(where).is_true()
		for second: int in range(first + 1, names.size()):
			var b: Rect2 = rects[names[second]].grow(-SLACK)
			var pair: String = "%s: %s and %s" % [where, names[first], names[second]]
			assert_bool(a.intersects(b)).override_failure_message(pair).is_false()
	for name: String in ["counter", "side", "buttons", "board", "shelf", "notes"]:
		var apart: bool = not books.get_global_rect().grow(-SLACK).intersects(rects[name])
		assert_bool(apart).override_failure_message("%s: slip over %s" % [where, name]).is_true()
