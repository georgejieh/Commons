extends GdUnitTestSuite
## ADR 0022's notice (P4.19): a live correction brings the state's notice over whatever
## screen the player is on, saying what the event says and never a dark figure's true
## value; it holds the table's events until a key or button acknowledges it, keeps the
## focus and takes every other key; it shows again for the next correction, and never on
## a replay, a reload or a table that joins the run. It fits the screen at its longest.

const SEED: int = 7211

var _app: DemoApp
var _lines: PackedStringArray = []
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	AppKit.fresh_saves(self)
	_lines.clear()
	_app = AppKit.make(self)
	_app.controller.live_search = false
	_app.controller.file_watch.report = func(line: String) -> void: _lines.append(line)


func after_test() -> void:
	Settings.set_value(TextSize.SETTING, 0)
	get_tree().root.size = _was_size
	Saves.run_service().delete()
	Saves.profile_service().delete()
	ArtStages.latch_value(0.0)


func _loop() -> RunLoop:
	return _app.controller.run_loop()


## A live event as the controller sends one.
func _send(correction: BooksCorrection) -> void:
	var event: RunEvent = RunEvent.new(RunEvent.Type.BOOKS_CORRECTED, 0, 1)
	event.correction = correction
	_app.controller.event_emitted.emit(event)
	await await_idle_frame()


func _raised() -> BooksCorrection:
	var correction: BooksCorrection = BooksCorrection.new()
	correction.add("coupons", 12, 120)
	correction.norm_added = 900
	correction.price_added = 900
	return correction


func _start_full_run() -> void:
	_app.controller.file_watch.release = true
	assert_bool(_app.new_run(SEED, true)).is_true()


## A figure changed behind the controller, then one honest command, as a release build
## sees it: the detector corrects the books and the notice comes over the table.
func test_a_live_correction_brings_the_notice_over_the_table_and_holds_it() -> void:
	_start_full_run()
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	var coupons: int = _loop().state.coupons
	_loop().state.coupons = coupons + 500
	assert_bool(ControllerScript.new().act(_app.controller)).is_true()
	await await_idle_frame()
	var notice: BooksNotice = _app.notice
	assert_bool(notice.is_showing()).is_true()
	var recorded: String = TranslationServer.translate("notice.figure").format(
		{"name": "Coupons", "recorded": coupons, "entered": coupons + 500}
	)
	assert_array(Array(notice.shown_lines())).contains([recorded])
	var events: EventPlayer = table.get("_player")
	assert_bool(events.is_processing()).is_false()
	assert_object(get_viewport().gui_get_focus_owner()).is_same(notice.acknowledge_button())
	await TestInput.tap_key(self, KEY_ESCAPE)
	assert_bool(notice.is_showing()).is_true()
	assert_bool(_app.menu_is_open()).is_false()
	var pause: PauseMenu = table.get("_pause")
	assert_bool(pause.visible).is_false()
	await TestInput.tap_key(self, KEY_ENTER)
	assert_bool(notice.is_showing()).is_false()
	assert_bool(events.is_processing()).is_true()
	assert_array(Array(_lines)).is_empty()


## Loading the corrected run replays its books command, and the table that opens on it
## replays the Quota's log: neither is live, so no notice shows.
func test_no_notice_on_a_reload_or_a_table_joining_the_run() -> void:
	_start_full_run()
	_loop().state.coupons += 300
	ControllerScript.new().act(_app.controller)
	await await_idle_frame()
	assert_bool(_app.notice.is_showing()).is_true()
	await TestInput.tap_key(self, KEY_ENTER)
	_app.resume_to_screen()
	await await_idle_frame()
	assert_bool(_app.notice.is_showing()).is_false()
	var replayed: int = 0
	for event: RunEvent in _app.controller.set_events():
		replayed += 1 if event.type == RunEvent.Type.BOOKS_CORRECTED else 0
	assert_int(replayed).is_equal(1)
	_app.show_screen("table", true)
	await await_idle_frame()
	assert_bool(_app.notice.is_showing()).is_false()


## The notice comes over each of a run's screens off the table too, and a gamepad's A
## acknowledges it. A second correction waits behind the first and shows after it.
func test_the_notice_on_every_kind_of_screen_and_every_time() -> void:
	_app.new_run(SEED)
	var driver: ControllerScript = ControllerScript.new()
	driver.play_to(self, _app.controller, RunController.AWAIT_SET_OVER)
	_app.show_screen("set_summary", true)
	await await_idle_frame()
	await _shown_and_acknowledged()
	_app.controller.finish_set()
	for screen_id: String in ["store", "black_market", "reeducation"]:
		_app.show_screen(screen_id, screen_id == "store")
		await await_idle_frame()
		await _shown_and_acknowledged()
	await _send(_raised())
	await _send(BooksCorrection.new())
	assert_int(_app.notice.waiting()).is_equal(1)
	await TestInput.tap_key(self, KEY_ENTER)
	assert_bool(_app.notice.is_showing()).is_true()
	var seal: String = TranslationServer.translate("notice.seal.title")
	assert_array(Array(_app.notice.shown_lines())).contains([seal])
	await TestInput.tap_key(self, KEY_ENTER)
	assert_bool(_app.notice.is_showing()).is_false()


func _shown_and_acknowledged() -> void:
	await _send(_raised())
	assert_bool(_app.notice.is_showing()).is_true()
	await await_idle_frame()
	assert_object(get_viewport().gui_get_focus_owner()).is_same(_app.notice.acknowledge_button())
	await TestInput.tap_pad(self, JOY_BUTTON_A)
	assert_bool(_app.notice.is_showing()).is_false()


## What the event says, line by line: a raise with its percents, a lowered meter that
## went dark with only the value reported, and a broken seal with no figures at all.
func test_the_notice_says_what_the_event_says() -> void:
	var none: Array[String] = []
	var raised: BooksNoticeText = BooksNoticeText.of(_raised(), none)
	assert_str(raised.title).is_equal(TranslationServer.translate("notice.title"))
	var lines: Array = Array(raised.lines)
	(
		assert_array(lines)
		. contains(
			[
				"Coupons: recorded as 12, now entered as 120.",
				TranslationServer.translate("notice.norm").format({"percent": 900}),
				TranslationServer.translate("notice.prices").format({"percent": 900}),
			]
		)
	)
	assert_str(raised.filed).is_equal(TranslationServer.translate("notice.filed"))
	var lowered: BooksCorrection = BooksCorrection.new()
	lowered.add("famine", 47, 3)
	lowered.dark.append("famine")
	var dark: BooksNoticeText = BooksNoticeText.of(lowered, none)
	assert_int(dark.lines.size()).is_equal(1)
	assert_str(dark.lines[0]).contains("3").contains(ShownFigures.none_reported())
	assert_str(" ".join(dark.all_lines())).not_contains("47")
	# A meter dark before this correction keeps its true value unprinted when raised.
	var risen: BooksCorrection = BooksCorrection.new()
	risen.add("denunciation", 41, 60)
	var already: Array[String] = ["denunciation"]
	assert_str(" ".join(BooksNoticeText.of(risen, already).all_lines())).not_contains("41")
	var seal: BooksNoticeText = BooksNoticeText.of(BooksCorrection.new(), none)
	assert_str(seal.title).is_equal(TranslationServer.translate("notice.seal.title"))
	assert_array(Array(seal.lines)).is_empty()


## The longest notice, every figure corrected, fits each screen size with its button.
func test_the_longest_notice_fits_the_screen() -> void:
	_app.new_run(SEED)
	var longest: BooksCorrection = BooksCorrection.new()
	longest.add("coupons", 999999, 1)
	longest.add("progress", 1.0, 9.99e15)
	for figure: String in ["famine", "denunciation", "resentment", "norm"]:
		longest.add(figure, 99, 0)
		longest.dark.append(figure)
	longest.norm_added = 900
	longest.price_added = 900
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		# The notice takes the text size as it is shown.
		await _send(longest)
		for screen_size: Vector2i in ClipCheck.SIZES:
			get_tree().root.size = screen_size
			await await_idle_frame()
			await await_idle_frame()
			var screen: Rect2 = get_tree().root.get_visible_rect().grow(ClipCheck.SLACK)
			# The notice covers the whole screen, so nothing under it takes a click, and its
			# sheet sits in the middle.
			var whole: Rect2 = get_tree().root.get_visible_rect()
			(
				assert_bool(_app.notice.get_global_rect().grow(ClipCheck.SLACK).encloses(whole))
				. is_true()
			)
			var sheet: Rect2 = (
				_app.notice.acknowledge_button().get_parent_control().get_global_rect()
			)
			var off: Vector2 = sheet.get_center() - whole.get_center()
			assert_float(absf(off.x)).override_failure_message(str(sheet)).is_less(4.0)
			assert_float(absf(off.y)).override_failure_message(str(sheet)).is_less(4.0)
			for node: Node in _app.notice.find_children("*", "Control", true, false):
				var control: Control = node as Control
				if not control.is_visible_in_tree() or control is ColorRect:
					continue
				var rect: Rect2 = control.get_global_rect()
				var where: String = "%s %s at %s" % [screen_size, control.get_path(), rect]
				assert_bool(screen.encloses(rect)).override_failure_message(where).is_true()
			_clips(_app.notice, str(screen_size))
		await TestInput.tap_key(self, KEY_ENTER)


## Nothing under root clips, as ClipCheck says (ADR 0034).
func _clips(root: Node, where: String) -> void:
	var problems: PackedStringArray = []
	ClipCheck.check(root, "%s at text size %d" % [where, TextSize.level()], problems)
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()
