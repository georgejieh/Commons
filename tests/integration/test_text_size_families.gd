extends GdUnitTestSuite
## Each paper that prints one item of a family is built with every item of that family at
## the largest text size, on both screens, and nothing on it clips (ADR 0034). The
## families covered here are the ones no other suite already runs at every size: Cadres
## on the shops' cards and the board, Directive documents in the store, tutorial slips
## and one-time tips, villager speech, the table's shouts, keyword slips, the stake
## tickets and the longest names. The rest run at every size in their own suites: debuffs
## (test_debuff_ui), envelopes and the shops (test_shop_layout), endings and epilogue
## lines (test_ending_screen), the books notice (test_books_notice), households and
## stakes on run setup and the collection (test_meta_screens), and every name through
## every paper (test_readability).

const SEED: int = 5101
const SAVE_PATH: String = "user://test_text_size_families/run.json"
const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 800)]
const LARGEST: int = 2
## The longest name a run can print: the longest given name in the pools and a typed
## surname as long as it may be, in the widest letter.
const LONGEST_GIVEN: String = "Changzheng"
const LONGEST_SURNAME: String = "Wwwwwwwwwwww"
## The table's seat width, where a villager speaks.
const SEAT: Vector2 = Vector2(380, 0)

var _app: DemoApp
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)
	_app.new_run(SEED)
	Settings.set_value(TextSize.SETTING, LARGEST)


func after_test() -> void:
	Settings.set_value(TextSize.SETTING, 0)
	Settings.set_value("reduced_motion", false)
	get_tree().root.size = _was_size
	Saves.run_service().delete()
	Saves.profile_service().delete()


func _loop() -> RunLoop:
	return _app.controller.get("_loop")


func _to_store() -> void:
	var driver: ControllerScript = ControllerScript.new()
	while _app.controller.awaiting() != RunController.AWAIT_SET_OVER:
		driver.act(_app.controller)
	_app.controller.finish_set()


func _clips(root: Node, where: String, problems: PackedStringArray) -> void:
	ClipCheck.check(root, "%s on %s" % [where, get_tree().root.size], problems)


func _assert_none(problems: PackedStringArray) -> void:
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()


## Every Cadre on the state store's and the black market's cards, three at a time.
func test_every_cadre_fits_its_shop_card() -> void:
	_to_store()
	var problems: PackedStringArray = []
	for screen: Vector2i in SIZES:
		get_tree().root.size = screen
		var counters: Dictionary[String, Array] = {
			"store": RunLoop.DEFAULT_CADRES.cadres, "black_market": RunLoop.DEFAULT_MARKET.cadres
		}
		for screen_id: String in counters:
			var ids: Array[String] = []
			for cadre: ModifierDef in counters[screen_id]:
				ids.append(cadre.id)
			for start: int in range(0, ids.size(), 3):
				var stock: Array[String] = ids.slice(start, start + 3)
				var shop: RunShop = _loop().market if screen_id == "black_market" else _loop().shop
				# The run's pool holds only what it has open: every Cadre of the counter here.
				shop.set("_pool", counters[screen_id])
				shop.set("_stock", stock)
				var store: StoreScreen = _app.show_screen(screen_id, true)
				await await_idle_frame()
				await await_idle_frame()
				_clips(store.get("_counter"), "%s %s" % [screen_id, stock], problems)
	_assert_none(problems)


## Every Cadre's name on a full board's badge, and its tooltip no wider than the screen.
func test_every_cadre_fits_the_board_and_its_tip() -> void:
	var board: NoticeBoard = auto_free(NoticeBoard.new())
	_app.add_child(board)
	board.setup(6, StoreScreen.BOARD_BOX)
	var tile: float = board.tile_size(6).x - CadreBadge.NAME_MARGIN * 2.0
	var font: Font = board.get_theme_default_font()
	var tip_size: int = TextSize.px(CommonsTheme.STYLE.body_size)
	for cadre: ModifierDef in RunLoop.all_cadres():
		var name: String = tr(cadre.name_key)
		var fitted: int = CadreBadge.name_size(font, name, tile)
		assert_int(fitted).is_greater_equal(TextSize.least(CadreBadge.LEAST_NAME))
		(
			assert_bool(NameFit.words_fit(font, name, tile, fitted))
			. override_failure_message(name)
			. is_true()
		)
		var tip: String = ScreenKit.cadre_tip(_app.controller, cadre.id)
		for line: String in tip.split("\n"):
			var wide: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, tip_size).x
			assert_float(wide).override_failure_message(line).is_less(1280.0)
	for count: String in ["+999", "99s", "x9.9"]:
		var count_px: int = CadreBadge.count_size(font, count)
		var wide: float = font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, count_px).x
		assert_float(wide).override_failure_message(count).is_less_equal(CadreBadge.TICKET.x)


## Every Directive on the store's documents, two at a time.
func test_every_directive_fits_its_store_document() -> void:
	_to_store()
	var ids: Array[String] = []
	for directive: DirectiveDef in RunLoop.DEFAULT_DIRECTIVES.directives:
		ids.append(directive.id)
	var problems: PackedStringArray = []
	for screen: Vector2i in SIZES:
		get_tree().root.size = screen
		for start: int in range(0, ids.size(), 2):
			var stock: Array[String] = ids.slice(start, start + 2)
			_loop().shop.set("_directive_stock", stock)
			var store: StoreScreen = _app.show_screen("store", true)
			await await_idle_frame()
			await await_idle_frame()
			_clips(store.get("_directives"), "directives %s" % [stock], problems)
	_assert_none(problems)


## Every line Wang says in the arrival, on his slip.
func test_every_tutorial_line_fits_its_slip() -> void:
	var problems: PackedStringArray = []
	for screen: Vector2i in SIZES:
		get_tree().root.size = screen
		for key: String in _keys("tutorial.step."):
			var slip: TutorialSlip = auto_free(TutorialSlip.new())
			_app.add_child(slip)
			slip.say(tr(key))
			var avoid: Array[Rect2] = []
			slip.place(Rect2(Vector2(800, 400), Vector2(100, 100)), avoid, Vector2(1920, 1080))
			await await_idle_frame()
			assert_int(slip.text_size()).is_equal(TextSize.px(TutorialSlip.TEXT_SIZE))
			_clips(slip, key, problems)
	_assert_none(problems)


## Every one-time tip on its slip, in a full run.
func test_every_one_time_tip_fits_its_slip() -> void:
	var problems: PackedStringArray = []
	for screen: Vector2i in SIZES:
		get_tree().root.size = screen
		Saves.profile_service().delete()
		assert_bool(_app.new_run(SEED, true)).is_true()
		var host: Control = _app.show_screen("title", true)
		var slip: TipSlip = TipSlip.offer(host, _app, ProfileSeen.TIPS)
		assert_object(slip).is_not_null()
		await await_idle_frame()
		await await_idle_frame()
		var seen: int = 0
		while is_instance_valid(slip) and not slip.shown().is_empty():
			_clips(slip, slip.shown(), problems)
			seen += 1
			slip.got_it_button().pressed.emit()
			await await_idle_frame()
		assert_int(seen).is_equal(ProfileSeen.TIPS.size())
	_assert_none(problems)


## Every speech line, from the shared book, each family's own and the work team's, in a
## seat at the table's width under the longest surname.
func test_every_speech_line_fits_its_seat() -> void:
	var lines: Array[SpeechLine] = []
	lines.append_array(TableSpeech.BOOK.lines)
	lines.append_array(TableSpeech.VISIT.lines)
	var families: Array[FamilyDef] = []
	families.append_array(RunLoop.DEFAULT_VILLAGE.families)
	families.append_array(RunLoop.DEFAULT_VILLAGE.youth_templates)
	for family: FamilyDef in families:
		if family.speech != null:
			lines.append_array(family.speech.lines)
	var problems: PackedStringArray = []
	for screen: Vector2i in SIZES:
		get_tree().root.size = screen
		var panel: SeatPanel = auto_free(SeatPanel.new())
		_app.add_child(panel)
		panel.position = Vector2(100, 112)
		panel.size = SEAT
		panel.setup(1, _longest_surname())
		for line: SpeechLine in lines:
			panel.say(tr(line.text_key).format({"count": 16}))
			await await_idle_frame()
			_clips(panel, line.text_key, problems)
	_assert_none(problems)


## Every shout the table makes, at both tiers: each word over the longest line under
## it, and each line under the longest word, filled with the longest name.
func test_every_shout_fits_the_screen() -> void:
	Settings.set_value("reduced_motion", true)
	var words: Array[String] = []
	var lines: Array[String] = []
	for key: String in _keys("callout."):
		var shown: String = tr(key).format(_shout_fields())
		var line: bool = key.ends_with(".sub") or key.contains(".sub.") or key.ends_with(".you")
		(lines if line else words).append(shown)
	var longest_word: String = _longest(words)
	var longest_line: String = _longest(lines)
	var problems: PackedStringArray = []
	for screen: Vector2i in SIZES:
		get_tree().root.size = screen
		for tier: Callout.Tier in [Callout.Tier.CUT_IN, Callout.Tier.TAKEOVER]:
			for word: String in words:
				await _shout(word, longest_line, tier, problems)
			for line: String in lines:
				await _shout(longest_word, line, tier, problems)
	_assert_none(problems)


func _shout(word: String, line: String, tier: Callout.Tier, problems: PackedStringArray) -> void:
	var callout: Callout = auto_free(Callout.new())
	_app.add_child(callout)
	callout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await await_idle_frame()
	callout.shout(word, tier, ScreenKit.RED, line)
	await await_idle_frame()
	_clips(callout, "%s / %s %d" % [word, line, tier], problems)
	callout.queue_free()


func _shout_fields() -> Dictionary:
	return {
		"name": _longest_surname(),
		"progress": "999.9Q",
		"target": "999.9Q",
		"times": 9,
		"amount": "999.9Q",
		"card": tr("card.rank.10"),
		"ranks": "10 and 10",
	}


func _longest(texts: Array[String]) -> String:
	var longest: String = ""
	for text: String in texts:
		longest = text if text.length() > longest.length() else longest
	return longest


## Every keyword's slip: its meaning, with the meanings of the words it names.
func test_every_keyword_slip_fits_the_screen() -> void:
	var problems: PackedStringArray = []
	for screen: Vector2i in SIZES:
		get_tree().root.size = screen
		for id: String in Keywords.TERMS:
			var name: String = tr("keyword.%s.name" % id)
			var slip: Control = Keywords.slip(Keywords.meaning(id), name)
			auto_free(slip)
			_app.add_child(slip)
			await await_idle_frame()
			_clips(slip, "keyword %s" % id, problems)
	_assert_none(problems)


## Every stake's ticket, open, with its name.
func test_every_stake_fits_its_ticket() -> void:
	var problems: PackedStringArray = []
	for index: int in RunStakes.STAKES.stakes.size():
		var stake: StakeDef = RunStakes.STAKES.stakes[index]
		var ticket: StakeTicket = auto_free(StakeTicket.new(index, true, tr(stake.name_key)))
		_app.add_child(ticket)
		await await_idle_frame()
		_clips(ticket, stake.id, problems)
	_assert_none(problems)


## The longest name a run can print, on the Set intro's seated line and the settings
## screen's family name.
func test_the_longest_names_fit() -> void:
	var data: ProfileData = Profile.read(Saves.profile_service())
	data.surname = LONGEST_SURNAME
	Profile.write(Saves.profile_service(), data)
	assert_bool(_app.new_run(SEED, true)).is_true()
	var names: RunNames = _loop().state.names
	assert_bool(names.given.is_empty()).is_false()
	for family: String in names.given:
		names.given[family] = LONGEST_GIVEN
	var problems: PackedStringArray = []
	for screen: Vector2i in SIZES:
		get_tree().root.size = screen
		for screen_id: String in ["set_intro", "settings"]:
			var shown: Node = _app.show_screen(screen_id, true)
			await await_idle_frame()
			await await_idle_frame()
			_clips(shown, screen_id, problems)
	_assert_none(problems)


## Prose on its own paper scrolls when it is too long (ADR 0034): it offers focus only
## then, up and down on a keyboard or gamepad move it, and with a cap it stands no taller.
func test_long_prose_scrolls_on_its_paper_by_keys() -> void:
	var lines: PackedStringArray = []
	for key: String in _keys("tutorial.step."):
		lines.append(tr(key))
	var words: Label = ScreenKit.label("\n".join(lines), 22)
	var scroll: ProseScroll = auto_free(ProseScroll.new(words))
	_app.add_child(scroll)
	scroll.size = Vector2(500, 300)
	scroll.fit_to(300.0)
	await await_idle_frame()
	await await_idle_frame()
	assert_float(scroll.custom_minimum_size.y).is_equal(300.0)
	assert_bool(scroll.can_scroll()).is_true()
	scroll.grab_focus()
	var down: InputEventAction = InputEventAction.new()
	down.action = "ui_down"
	down.pressed = true
	scroll.call("_gui_input", down)
	assert_int(scroll.scroll_vertical).is_greater(0)
	var short: ProseScroll = auto_free(ProseScroll.new(ScreenKit.label("One line", 22)))
	_app.add_child(short)
	short.size = Vector2(500, 300)
	short.fit_to(300.0)
	await await_idle_frame()
	await await_idle_frame()
	assert_bool(short.can_scroll()).is_false()
	assert_float(short.custom_minimum_size.y).is_less(300.0)


## Every key of the table that starts with prefix.
func _keys(prefix: String) -> Array[String]:
	var keys: Array[String] = []
	for key: String in SourceScan.table_keys():
		if key.begins_with(prefix):
			keys.append(key)
	return keys


## The village's longest surname, as a seat is named by it.
func _longest_surname() -> String:
	var longest: String = ""
	for family: FamilyDef in RunLoop.DEFAULT_VILLAGE.families:
		var name: String = tr(family.name_key)
		longest = name if name.length() > longest.length() else longest
	for key: String in RunLoop.DEFAULT_VILLAGE.youth_surnames:
		var name: String = tr(key)
		longest = name if name.length() > longest.length() else longest
	return longest
