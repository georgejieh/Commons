extends GdUnitTestSuite
## A scripted smoke test of the demo UI (ADR 0017): every demo screen
## opens over a live run, back navigation keeps the run, and the table drives a whole
## Set to its summary through the same buttons a player presses.

const SEED: int = 4301
const SCREENS: Array[String] = [
	"title",
	"set_intro",
	"table",
	"set_summary",
	"store",
	"year_summary",
	"settings",
	"demo_complete",
	"dossier",
	"run_setup",
	"round_summary",
	"black_market",
	"reeducation",
	"ending",
	"collection",
	"village_history",
]

var _app: App


func before_test() -> void:
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)
	_app.new_run(SEED)


func after_test() -> void:
	Settings.set_value("post_process", SettingsStore.DEFAULTS.get("post_process"))
	Settings.set_value("reduced_motion", SettingsStore.DEFAULTS.get("reduced_motion"))
	Saves.run_service().delete()


func test_every_demo_screen_opens() -> void:
	for screen_id: String in SCREENS:
		var screen: Node = _app.show_screen(screen_id, true)
		await await_idle_frame()
		assert_object(screen).is_not_null()
		assert_str(_app.switcher.current_id()).is_equal(screen_id)


func test_back_navigation_keeps_the_run() -> void:
	_app.show_screen(App.TABLE, true)
	await await_idle_frame()
	var was: Dictionary = _app.controller.state_copy().to_dict()
	_app.show_screen(App.SETTINGS)
	await await_idle_frame()
	_app.back()
	await await_idle_frame()
	assert_str(_app.switcher.current_id()).is_equal(App.TABLE)
	assert_dict(_app.controller.state_copy().to_dict()).is_equal(was)


func test_the_table_plays_a_set_to_its_summary() -> void:
	var table: TableScreen = _app.show_screen(App.TABLE, true)
	await await_idle_frame()
	var driver: ControllerScript = ControllerScript.new()
	for _turn: int in 600:
		if _app.switcher.current_id() == App.SET_SUMMARY:
			break
		table.skip_events()
		if _app.switcher.current_id() != "table":
			break
		_press(table, driver)
		await await_idle_frame()
	assert_str(_app.switcher.current_id()).is_equal(App.SET_SUMMARY)
	# The report fills its Quota bar to what was scored and seals it met or short.
	var report: SetSummaryScreen = _app.switcher.current()
	var state: RunState = _app.controller.state_copy()
	var target: float = _app.controller.figures.target()
	var sealed: Callable = func() -> bool: return not report.bar().seal_word().is_empty()
	await TestWait.until(self, sealed, "the Quota bar to fill and be sealed")
	assert_float(report.bar().value).is_equal_approx(minf(state.set_progress, target), 0.5)
	var met: bool = state.set_progress >= target
	assert_bool(report.bar().is_met()).is_equal(met)
	var word: String = tr("table.quota_met" if met else "summary.short").to_upper()
	assert_str(report.bar().seal_word()).is_equal(word)
	# Then what it paid or cost is counted in.
	var now: Array[Control] = report.after
	await TestWait.until(self, _shown.bind(now), "what the Quota paid or cost to be shown")
	for piece: Control in now:
		assert_float(piece.modulate.a).is_equal_approx(1.0, 0.01)


## Takes the player's turn through the table's own buttons and hand model.
func _press(table: TableScreen, driver: ControllerScript) -> void:
	match _app.controller.awaiting():
		RunController.AWAIT_BID:
			table.actions.decline.pressed.emit()
		RunController.AWAIT_NEED:
			table.need_panel.declared.emit(ControllerScript.NEED)
		RunController.AWAIT_PLAY:
			var ids: Array[int] = driver.choose_play(_app.controller)
			if ids.is_empty():
				table.actions.pass_turn.pressed.emit()
				return
			for card_id: int in ids:
				_app.hand.toggle(card_id)
			assert_bool(table.actions.play.disabled).is_false()
			table.actions.play.pressed.emit()


## After a command the buttons stay off until the bots' plays have been shown.
func test_buttons_lock_while_events_play() -> void:
	var table: TableScreen = _app.show_screen(App.TABLE, true)
	await await_idle_frame()
	var driver: ControllerScript = ControllerScript.new()
	for _turn: int in 200:
		table.skip_events()
		if _app.controller.awaiting() == RunController.AWAIT_PLAY:
			break
		_press(table, driver)
		await await_idle_frame()
	assert_int(_app.controller.awaiting()).is_equal(RunController.AWAIT_PLAY)
	table.skip_events()
	var ids: Array[int] = driver.choose_play(_app.controller)
	for card_id: int in ids:
		_app.hand.toggle(card_id)
	if ids.is_empty():
		table.actions.pass_turn.pressed.emit()
	else:
		table.actions.play.pressed.emit()
	if _app.controller.awaiting() == RunController.AWAIT_PLAY:
		assert_bool(table.actions.pass_turn.disabled).is_true()
		assert_bool(table.actions.play.disabled).is_true()


## A shortcut presses the same button a click does: Pass on the bid turns the call down.
func test_a_shortcut_presses_its_button() -> void:
	var table: TableScreen = _app.show_screen(App.TABLE, true)
	await await_idle_frame()
	table.skip_events()
	if _app.controller.awaiting() != RunController.AWAIT_BID:
		return
	var shortcut: InputEventAction = InputEventAction.new()
	shortcut.action = "commons_pass"
	shortcut.pressed = true
	TestInput.push(self, shortcut)
	assert_int(_app.controller.awaiting()).is_not_equal(RunController.AWAIT_BID)


## The print pass follows its setting.
func test_the_post_process_follows_its_setting() -> void:
	var was: bool = bool(Settings.value("post_process"))
	Settings.set_value("post_process", false)
	assert_bool(_app.post.is_on()).is_false()
	Settings.set_value("post_process", true)
	assert_bool(_app.post.is_on()).is_true()
	Settings.set_value("post_process", was)


## Sort cycles rank, suit and groups, and the button names the current one.
func test_sort_cycles_and_names_its_mode() -> void:
	var table: TableScreen = _app.show_screen(App.TABLE, true)
	await await_idle_frame()
	table.skip_events()
	var seen: Array[String] = []
	for _press_count: int in 3:
		table.actions.sort.pressed.emit()
		seen.append(table.actions.sort.text)
	assert_int(seen.size()).is_equal(3)
	assert_bool(seen[0] != seen[1] and seen[1] != seen[2]).is_true()
	assert_str(table.actions.sort.tooltip_text).is_not_empty()


## The rules card and the menu sit above the table and block clicks to it.
func test_overlays_open_above_the_table() -> void:
	var table: TableScreen = _app.show_screen(App.TABLE, true)
	await await_idle_frame()
	table.actions.rules.pressed.emit()
	var sheet: Control = table.cheat_sheet
	assert_bool(sheet.visible).is_true()
	assert_int(sheet.get_index()).is_equal(table.get_child_count() - 1)
	assert_int(sheet.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	sheet.visible = false
	var hud: TableHud = table.hud
	hud.menu.pressed.emit()
	var pause: Control = table.pause
	assert_bool(pause.visible).is_true()
	assert_int(pause.get_index()).is_equal(table.get_child_count() - 1)


## Joining a Set mid-way replays its earlier events without raising their banners.
func test_rejoining_the_table_raises_no_old_banner() -> void:
	var driver: ControllerScript = ControllerScript.new()
	# An array, so the count the handler keeps is the one the loop reads.
	var ended: Array[int] = [0]
	_app.controller.event_emitted.connect(
		func(event: RunEvent) -> void:
			if event.round_event != null and event.round_event.type == RoundEvent.Type.ROUND_ENDED:
				ended[0] += 1
	)
	while not (ended[0] >= 1 and _app.controller.awaiting() == RunController.AWAIT_BID):
		if not driver.act(_app.controller):
			break
	assert_int(ended[0]).override_failure_message("no round ended").is_greater_equal(1)
	var table: TableScreen = _app.show_screen(App.TABLE, true)
	var moments: TableMoments = table.moments
	# Timed: that no banner is raised is seen only by giving one the time to come.
	await await_millis(400)
	assert_bool(moments.callout.is_showing()).is_false()


func test_the_ledger_counts_each_play_once() -> void:
	var table: TableScreen = _app.show_screen(App.TABLE, true)
	var scored: Dictionary[int, float] = {}
	var plays: Array[int] = [0]
	_app.controller.event_emitted.connect(
		func(event: RunEvent) -> void:
			if event.type == RunEvent.Type.PLAY_SCORED:
				scored[event.seat] = scored.get(event.seat, 0.0) + event.amount
				plays[0] += 1
	)
	var driver: ControllerScript = ControllerScript.new()
	while plays[0] < 3:
		if not driver.act(_app.controller):
			break
	table.skip_events()
	assert_int(plays[0]).is_greater_equal(3)
	var ledger: Ledger = table.ledger
	for seat: int in scored:
		assert_float(ledger.total_of(seat)).is_equal_approx(scored[seat], 0.001)


func test_a_stocked_plot_opens_the_swap_sheet_over_the_table() -> void:
	var loop: RunLoop = _app.controller.run_loop()
	loop.state.inventory.plot.append(
		CardInstance.new(CardInstance.FIRST_PLOT_ID, 12, 0, CardInstance.Origin.PLOT)
	)
	var table: TableScreen = _app.show_screen(App.TABLE, true)
	await await_idle_frame()
	var sheet: PlotSwapSheet = table.swap_sheet
	for _turn: int in 40:
		if sheet.is_open():
			break
		table.skip_events()
		if _app.controller.awaiting() == RunController.AWAIT_BID:
			table.actions.decline.pressed.emit()
		await await_idle_frame()
	assert_bool(sheet.is_open()).is_true()
	assert_str(_app.switcher.current_id()).is_equal(App.TABLE)
	# Keeping the hand closes the sheet, with the round ready to play at the same table.
	sheet.keep_button().pressed.emit()
	await await_idle_frame()
	assert_bool(sheet.is_open()).is_false()
	assert_object(_app.switcher.current()).is_same(table)
	assert_int(_app.controller.awaiting()).is_not_equal(RunController.AWAIT_SWAP)


## A curve the first scoring round beats many times over.
func _easy_sets() -> SetConfig:
	var params: SetParams = SetConfig.DEFAULT_PARAMS.duplicate()
	params.targets = params.targets.duplicate()
	params.targets.fill(0.01)
	return SetConfig.new(params)


## An overfulfilled Quota is sealed met, then overfulfilled in gold; the coupons count
## in the bonus with the reward, and a second line says how far the norm rose. Reduced
## motion shows the same at once.
func test_an_overfulfilled_quota_is_sealed_twice_and_counts_the_bonus() -> void:
	for reduced: bool in [false, true]:
		Settings.set_value("reduced_motion", reduced)
		_app.controller.start_run(SEED, RunScript.bots(), _easy_sets())
		var driver: ControllerScript = ControllerScript.new()
		while driver.act(_app.controller):
			pass
		assert_int(_app.controller.awaiting()).is_equal(RunController.AWAIT_SET_OVER)
		var steps: int = _app.controller.figures.over_steps()
		assert_int(steps).is_equal(SetConfig.DEFAULT_PARAMS.over_max_steps)
		var report: SetSummaryScreen = _app.show_screen(App.SET_SUMMARY, true)
		await await_idle_frame()
		if not reduced:
			assert_str(report.over_seal_word()).is_empty()
		var over: Callable = func() -> bool: return not report.over_seal_word().is_empty()
		await TestWait.until(self, over, "the bar to fill and be sealed twice")
		assert_str(report.bar().seal_word()).is_equal(tr("table.quota_met").to_upper())
		assert_str(report.over_seal_word()).is_equal(tr("summary.over").to_upper())
		var now: Array[Control] = report.after
		var coupons: String = str(_app.controller.state_copy().coupons)
		var counted: Callable = func() -> bool:
			return _shown(now) and _number_in(now[0], 0).text == coupons
		await TestWait.until(self, counted, "the pay and the bonus to be counted in")
		assert_int(now.size()).is_equal(3)
		var bonus: int = steps * SetConfig.DEFAULT_PARAMS.over_bonus_coupons
		assert_int(_app.controller.figures.over_bonus()).is_equal(bonus)
		var paid: int = _app.controller.figures.quota_reward() + bonus
		var line: Label = now[1]
		assert_str(line.text).is_equal(Strings.count("summary.paid", paid))
		var norm: Label = now[2]
		var added: int = steps * SetConfig.DEFAULT_PARAMS.norm_percent_per_step
		assert_str(norm.text).is_equal(report.norm_text())
		assert_str(norm.text).contains("%d%%" % added)
		var tile: Label = _number_in(now[0], 0)
		assert_str(tile.text).is_equal(str(_app.controller.state_copy().coupons))
	Settings.set_value("reduced_motion", false)


## The Set after shows its raised target with a note saying how far the norm rose.
func test_the_next_quota_shows_the_raised_norm() -> void:
	_app.controller.start_run(SEED, RunScript.bots(), _easy_sets())
	var driver: ControllerScript = ControllerScript.new()
	while driver.act(_app.controller):
		pass
	_app.controller.finish_set()
	_app.controller.leave_store()
	var percent: int = _app.controller.figures.norm_percent()
	assert_int(percent).is_greater(0)
	_app.show_screen(App.SET_INTRO, true)
	await await_idle_frame()
	var step: int = SetConfig.DEFAULT_PARAMS.norm_percent_per_step
	var note: String = tr("intro.norm").format({"percent": percent, "step": step})
	assert_bool(_has_label(_app.switcher.current(), note)).is_true()


## The number on a stat tile: the tile's index-th title label.
## True once every piece has faded fully in.
func _shown(pieces: Array[Control]) -> bool:
	return pieces.all(func(piece: Control) -> bool: return piece.modulate.a >= 0.999)


func _number_in(tile: Control, index: int) -> Label:
	var found: Array[Label] = []
	for node: Node in tile.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label.theme_type_variation == CommonsTheme.TITLE:
			found.append(label)
	return found[index]


func _has_label(root: Node, text: String) -> bool:
	for node: Node in root.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label.text == text:
			return true
	return false
