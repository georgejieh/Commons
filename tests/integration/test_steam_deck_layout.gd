extends GdUnitTestSuite
## Nothing clips at any text size (ADR 0034), at 1920x1080 and at 1280x800, the Steam
## Deck's screen. With the canvas_items stretch and expand aspect, a 16:10
## window shows a 1920x1200 canvas. Every screen and the table's menus are opened at each
## size on each screen, and ClipCheck says what clipping is. The Controls page (ADR 0035)
## is a screen of its own at the title and a page of the table's menu, so both are opened.

const SEED: int = 4301
const DECK: Vector2i = Vector2i(1280, 800)
const SCREENS_AT: Array[Vector2i] = [Vector2i(1920, 1080), DECK]

var _app: DemoApp
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	get_tree().root.size = DECK
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)
	_app.new_run(SEED)


func after_test() -> void:
	Settings.set_value(TextSize.SETTING, 0)
	get_tree().root.size = _was_size
	Saves.run_service().delete()


func test_the_canvas_is_16_by_10() -> void:
	var visible: Rect2 = get_tree().root.get_visible_rect()
	assert_float(visible.size.x / visible.size.y).is_equal_approx(1.6, 0.01)


## A window wider than 16:9, as a maximized one is, shows the same 1920 by 1080 canvas
## with bars at its sides: nothing is laid out for a wider one.
func test_a_wider_window_keeps_the_canvas() -> void:
	for window: Vector2i in [Vector2i(1920, 1017), Vector2i(2560, 1080), Vector2i(3440, 1440)]:
		get_tree().root.size = window
		await await_idle_frame()
		var visible: Rect2 = get_tree().root.get_visible_rect()
		assert_vector(visible.size).override_failure_message(str(window)).is_equal(
			Vector2(1920, 1080)
		)


func test_no_screen_clips_at_any_text_size() -> void:
	var problems: PackedStringArray = []
	for level: int in TextSize.count():
		for screen: Vector2i in SCREENS_AT:
			Settings.set_value(TextSize.SETTING, level)
			get_tree().root.size = screen
			for screen_id: String in DemoApp.SCREENS:
				if not ResourceLoader.exists(DemoApp.SCREENS[screen_id]):
					continue
				var shown: Node = _app.show_screen(screen_id, true)
				await await_idle_frame()
				await await_idle_frame()
				ClipCheck.check(shown, _where(screen_id, level, screen), problems)
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()


func test_the_table_menus_do_not_clip_at_any_text_size() -> void:
	var problems: PackedStringArray = []
	for level: int in TextSize.count():
		for screen: Vector2i in SCREENS_AT:
			Settings.set_value(TextSize.SETTING, level)
			get_tree().root.size = screen
			var table: TableScreen = _app.show_screen("table", true)
			await await_idle_frame()
			table.hud.menu.pressed.emit()
			await await_idle_frame()
			ClipCheck.check(table, _where("pause", level, screen), problems)
			var pause: PauseMenu = table.pause
			TestInput.press(self, pause.main, tr("pause.settings"))
			await await_idle_frame()
			ClipCheck.check(table, _where("pause settings", level, screen), problems)
			SettingsPanel.controls_button(pause.settings).pressed.emit()
			await await_idle_frame()
			ClipCheck.check(table, _where("pause controls", level, screen), problems)
			# Asking for a key prints its own words on the ticket.
			pause.controls_page().capture(KeyBindings.ACTIONS[0])
			await await_idle_frame()
			ClipCheck.check(table, _where("pause controls asking", level, screen), problems)
			pause.controls_page().cancel_capture()
			pause.visible = false
			var sheet: CheatSheet = table.cheat_sheet
			sheet.toggle(_app.controller)
			await await_idle_frame()
			ClipCheck.check(table, _where("cheat sheet", level, screen), problems)
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()


## The check itself catches text that grows past the screen's edge, a control off
## screen, a wrapped label with lines it cannot show, rich text taller than its box and
## type under the least size.
func test_the_check_catches_each_kind_of_clipping() -> void:
	var holder: Control = auto_free(Control.new())
	add_child(holder)
	var narrow: Label = Label.new()
	narrow.text = "A label far too long for the space left on the right"
	holder.add_child(narrow)
	narrow.position = Vector2(1700, 40)
	var lost: Panel = Panel.new()
	holder.add_child(lost)
	lost.position = Vector2(1900, 1190)
	lost.size = Vector2(200, 200)
	var cut: Label = Label.new()
	cut.text = "Several words that wrap onto more lines than are shown"
	cut.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cut.max_lines_visible = 1
	holder.add_child(cut)
	cut.position = Vector2(100, 400)
	cut.size = Vector2(120, 0)
	var tall: RichTextLabel = RichTextLabel.new()
	tall.text = "One line\nTwo lines\nThree lines\nFour lines"
	holder.add_child(tall)
	tall.position = Vector2(400, 400)
	tall.size = Vector2(300, 20)
	var small: Label = Label.new()
	small.text = "Small"
	small.add_theme_font_size_override("font_size", 12)
	holder.add_child(small)
	small.position = Vector2(800, 400)
	await await_idle_frame()
	var problems: PackedStringArray = []
	ClipCheck.check(holder, "sample", problems)
	assert_array(problems).override_failure_message("\n".join(problems)).has_size(5)


## A new size from the settings sheet shows on the sheet at once. The table under the
## menu is not built again mid-round: when the menu closes it is the same table, in the
## tree, with the run, the selection, the hand's sort and what it shows as they were, and
## nothing on it clips with the theme at the new size and its own pieces at the old. At
## the next deal it is built again at the new size, the sort kept, the old table gone
## and no search waiting.
func test_a_new_text_size_reaches_the_table_at_the_next_deal() -> void:
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	var view: RunTableView = _app.controller.table
	# A play made this round, so the next deal is a new one.
	var plays: Callable = func() -> bool:
		var seen: SeatView = view.seat_view()
		return seen != null and not seen.public.history.is_empty()
	assert_bool(await _play_until(table, plays)).is_true()
	var cards: Array[CardInstance] = _app.hand.cards()
	_app.hand.toggle(cards[0].id())
	table.keep_sort(HandView.Sort.SUIT)
	var before: Array = _round(table)
	var deals: int = _deals()
	table.hud.menu.pressed.emit()
	var pause: PauseMenu = table.pause
	TestInput.press(self, pause.main, tr("pause.settings"))
	await await_idle_frame()
	var note: String = tr("settings.text_size.table")
	assert_object(_labelled(pause, note)).override_failure_message(note).is_not_null()
	var largest: CheckBox = pause.find_child(SettingsPanel.TEXT_SIZE_BOX % 2, true, false)
	largest.button_pressed = true
	await await_idle_frame()
	await await_idle_frame()
	assert_int(TextSize.level()).is_equal(2)
	var chosen: CheckBox = SettingsPanel.chosen_text_size(pause)
	assert_bool(chosen.button_pressed and chosen.has_focus()).is_true()
	assert_int(chosen.get_theme_font_size("font_size")).is_equal(TextSize.px(26))
	pause.close()
	await await_idle_frame()
	await await_idle_frame()
	assert_object(_app.switcher.current()).is_same(table)
	assert_bool(table.is_inside_tree() and pause.is_inside_tree() and not pause.visible).is_true()
	assert_array(_round(table)).is_equal(before)
	var problems: PackedStringArray = []
	ClipCheck.check(table, "table after the menu", problems)
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()
	var you: Label = table.you
	assert_int(you.get_theme_font_size("font_size")).is_equal(28)
	var rebuilt: Callable = func() -> bool: return _app.switcher.current() != table
	assert_bool(await _play_until(table, rebuilt)).is_true()
	await await_idle_frame()
	assert_int(_deals()).is_greater(deals)
	assert_bool(is_instance_valid(table)).is_false()
	var opened: TableScreen = _app.switcher.current()
	assert_bool(opened.is_inside_tree()).is_true()
	var awaiting: int = _app.controller.awaiting()
	var start: bool = awaiting == RunController.AWAIT_BID or awaiting == RunController.AWAIT_PLAY
	assert_bool(start).override_failure_message(str(awaiting)).is_true()
	assert_int(_app.controller.searches_running()).is_equal(0)
	assert_int(opened.hand_view.sort_mode).is_equal(HandView.Sort.SUIT)
	# The new table is set at the new size: the prompt takes it whole, and the line over
	# the hand grows as far as its room between the notice and a lifted card lets it.
	var opened_actions: ActionBar = opened.actions
	var prompt_px: int = opened_actions.reading.get_theme_font_size("font_size")
	assert_int(prompt_px).is_equal(TextSize.px(24))
	var opened_you: Label = opened.you
	var you_px: int = opened_you.get_theme_font_size("font_size")
	assert_int(you_px).is_between(29, TextSize.px(28))
	var round_now: Array = _round(opened)
	assert_array(round_now[2]).override_failure_message("hand").is_equal(_hand_ids())
	assert_array(opened.pile.top_ids()).is_empty()
	ClipCheck.check(opened, "table at the next deal", problems)
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()


## Acts for the player, the table acting each step out at once, until done or the Set ends.
func _play_until(table: TableScreen, done: Callable) -> bool:
	var driver: ControllerScript = ControllerScript.new()
	for _step: int in 400:
		if done.call():
			return true
		var awaiting: int = _app.controller.awaiting()
		if awaiting == RunController.AWAIT_SET_OVER or awaiting == RunController.AWAIT_RUN_OVER:
			return false
		driver.act(_app.controller)
		if is_instance_valid(table) and table.is_inside_tree():
			table.skip_events()
		await await_idle_frame()
	return done.call()


func _deals() -> int:
	var deals: int = 0
	for event: RunEvent in _app.controller.set_events():
		deals += 1 if event.type == RunEvent.Type.DEALT else 0
	return deals


func _hand_ids() -> Array[int]:
	var ids: Array[int] = []
	for card: CardInstance in _app.hand.cards():
		ids.append(card.id())
	return ids


func _labelled(root: Node, text: String) -> Label:
	for node: Node in root.find_children("*", "Label", true, false):
		if (node as Label).text == text:
			return node as Label
	return null


## Display type holds its size at every text size (ADR 0034): the headline and title
## steps, and any base of the display size or more.
func test_display_type_holds_its_size() -> void:
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		var theme: Theme = CommonsTheme.build()
		var style: UiStyle = CommonsTheme.STYLE
		assert_int(theme.get_font_size("font_size", CommonsTheme.HEADLINE)).is_equal(
			style.headline_size
		)
		assert_int(theme.get_font_size("font_size", CommonsTheme.TITLE)).is_equal(style.title_size)
		assert_int(TextSize.px(TextSize.PARAMS.display_text_px)).is_equal(
			TextSize.PARAMS.display_text_px
		)
		var body: int = TextSize.PARAMS.display_text_px - 1
		assert_int(TextSize.px(body)).is_equal(
			maxi(roundi(body * TextSize.factor()), TextSize.PARAMS.least_text_px)
		)


## Away from the table the screen under the menu is built again when it closes, with the
## way back kept.
func test_a_new_text_size_rebuilds_a_run_screen_when_the_menu_closes() -> void:
	_app.show_screen("title", true)
	var intro: Node = _app.show_screen("set_intro")
	await await_idle_frame()
	var menu: PauseMenu = _app.get("_menu")
	menu.open()
	TestInput.press(self, menu.main, tr("pause.settings"))
	await await_idle_frame()
	var large: CheckBox = menu.find_child(SettingsPanel.TEXT_SIZE_BOX % 1, true, false)
	large.button_pressed = true
	await await_idle_frame()
	await await_idle_frame()
	menu.close()
	await await_idle_frame()
	var rebuilt: Node = _app.switcher.current()
	assert_bool(rebuilt != intro).is_true()
	assert_str(_app.switcher.current_id()).is_equal("set_intro")
	assert_bool(_app.back()).is_true()
	assert_str(_app.switcher.current_id()).is_equal("title")


## The round as the run and the table hold it: what the run waits on, its events, the
## hand and its selection, the hand's sort and what the table shows.
func _round(table: TableScreen) -> Array:
	var ids: Array[int] = []
	for card: CardInstance in _app.hand.cards():
		ids.append(card.id())
	var view: HandView = table.hand_view
	return [
		_app.controller.awaiting(),
		_app.controller.set_events().size(),
		ids,
		_app.hand.selected_ids(),
		view.sort_mode,
		Array(_shown(table)),
	]


## What the table shows of the round: your line, each seat's name and count, the HUD.
func _shown(table: TableScreen) -> PackedStringArray:
	var you: Label = table.you
	var shown: PackedStringArray = [you.text]
	var seats: Dictionary[int, SeatPanel] = table.seats
	for seat: int in seats:
		for part: String in ["_name", "_count"]:
			var label: Label = seats[seat].get(part)
			shown.append(label.text)
	var hud: TableHud = table.hud
	shown.append(hud.coupons.text)
	return shown


func _where(screen_id: String, level: int, screen: Vector2i) -> String:
	return "%s at size %d on %dx%d" % [screen_id, level, screen.x, screen.y]
