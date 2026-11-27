extends GdUnitTestSuite
## ADR 0022's dark figures: every screen that shows Famine, Denunciation,
## Resentment or the Quota's target shows "None reported" for a dark one and never its
## true value, with no warning: no pulse, no sound and no dread on the board. The
## setback, or the death, still comes.

const SEED: int = 7213
## Values no other number on these screens shares.
const FAMINE: int = 83
const DENUNCIATION: int = 79
const RESENTMENT: int = 71
const FAMINE_LAYER: int = 0

var _app: DemoApp


func before_test() -> void:
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)
	_app.new_run(SEED)


func after_test() -> void:
	Saves.run_service().delete()
	ArtStages.stage_override = -1


func _loop() -> RunLoop:
	return _app.controller.run_loop()


## Puts the figures where no other number is and darkens those named, behind the
## controller, as only tests and tools do.
func _darken(figures: Array[String]) -> void:
	var state: RunState = _loop().state
	state.famine = FAMINE
	state.denunciation = DENUNCIATION
	state.resentment = RESENTMENT
	state.coupons = 5
	state.books.dark.assign(figures)
	_app.controller.reseal_book()


func _to_set_over() -> void:
	var driver: ControllerScript = ControllerScript.new()
	driver.play_to(self, _app.controller, RunController.AWAIT_SET_OVER)


## Every word a screen shows, joined.
static func _shown(screen: Node) -> String:
	var texts: PackedStringArray = []
	for node: Node in screen.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if not control.is_visible_in_tree():
			continue
		if control is Label:
			texts.append((control as Label).text)
		elif control is RichTextLabel:
			texts.append((control as RichTextLabel).get_parsed_text())
		elif control is Button:
			texts.append((control as Button).text)
	return " | ".join(texts)


func _never_shows(screen: Node, values: Array[int]) -> void:
	var words: String = _shown(screen)
	for value: int in values:
		assert_str(words).override_failure_message(words).not_contains(str(value))


func test_the_table_hud_shows_a_dark_meter_and_norm_as_none_reported() -> void:
	_darken(["famine", "norm"])
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	var hud: TableHud = table.hud
	assert_bool(hud.famine.visible).is_false()
	assert_bool(hud.denunciation.visible).is_true()
	assert_bool(hud.shows_meter("famine")).is_false()
	var target: String = Strings.score(_app.controller.figures.target())
	assert_str(hud.quota.text()).contains(ShownFigures.none_reported()).not_contains(target)
	assert_str(_shown(hud)).contains(ShownFigures.none_reported())
	# A change to a dark meter moves nothing that can be seen: no tween, so no pulse.
	hud.nudge_meter("famine", 10)
	var tweens: Dictionary = hud.get("_tweens")
	assert_bool(tweens.has("famine")).is_false()


func test_a_dark_meter_makes_no_sound_and_no_dread() -> void:
	var mark: int = TableSounds.METERS.famine.low
	var state: RunState = _loop().state
	state.famine = mark
	_app.controller.reseal_book()
	var rise: RunEvent = RunEvent.new(RunEvent.Type.METER_CHANGED, Seats.NONE, 5, 0.0, "famine")
	var before: int = Audio.effects.next_take(AudioEvents.METER_ROSE)
	state.books.dark.assign(["famine"])
	TableSounds.play(rise, Seats.NONE, _app.controller)
	assert_int(Audio.effects.next_take(AudioEvents.METER_ROSE)).is_equal(before)
	state.books.dark.clear()
	TableSounds.play(rise, Seats.NONE, _app.controller)
	var sounds: int = SfxPlayer.BANK.sound(AudioEvents.METER_ROSE).streams.size()
	if sounds > 1:
		assert_int(Audio.effects.next_take(AudioEvents.METER_ROSE)).is_not_equal(before)
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	var dread: DreadLayers = table.dread
	var copy: RunState = _app.controller.state_copy()
	copy.famine = 90
	dread.refresh(RunView.new(copy), true)
	assert_float(dread.board.targets[FAMINE_LAYER]).is_greater(0.2)
	copy.books.dark.assign(["famine"])
	dread.refresh(RunView.new(copy), true)
	assert_float(dread.board.targets[FAMINE_LAYER]).is_less(0.1)


func test_the_quota_report_shows_none_reported_and_no_rise() -> void:
	_to_set_over()
	_darken(["famine", "norm"])
	var summary: SetSummaryScreen = _app.show_screen("set_summary", true)
	await await_idle_frame()
	var words: String = _shown(summary)
	assert_str(words).contains(ShownFigures.none_reported())
	_never_shows(summary, [FAMINE])
	var target: String = Strings.score(_app.controller.figures.target())
	assert_str(summary.bar().text()).not_contains(target)
	assert_str(summary.over_seal_word()).is_empty()


func test_the_set_intro_hides_a_dark_norms_target() -> void:
	_darken(["norm"])
	var intro: Node = _app.show_screen("set_intro", true)
	await await_idle_frame()
	var rounds: int = _app.max_rounds()
	var hidden: String = tr("intro.target.unreported").format({"rounds": rounds})
	var shown: String = tr("intro.target").format(
		{"target": Strings.score(_app.controller.figures.target()), "rounds": rounds}
	)
	assert_str(_shown(intro)).contains(hidden).not_contains(shown)


func test_the_black_market_shows_a_dark_resentment_as_none_reported() -> void:
	_to_set_over()
	_app.controller.finish_set()
	_darken(["resentment"])
	var market: StoreScreen = _app.show_screen("black_market", true)
	await await_idle_frame()
	var count: Label = market.resentment
	assert_str(count.text).is_equal(ShownFigures.none_reported())
	_never_shows(market, [RESENTMENT])


func test_the_year_and_round_pages_and_the_ending_show_none_reported() -> void:
	_darken(["famine", "denunciation"])
	for screen_id: String in ["year_summary", "round_summary"]:
		var page: Node = _app.show_screen(screen_id, true)
		await await_idle_frame()
		_never_shows(page, [FAMINE, DENUNCIATION])
	# A dark Famine at its death still ends the run as Famine does.
	_loop().state.famine = RunDefaults.METERS.famine.death
	_app.controller.reseal_book()
	assert_str(_app.controller.seats.ending().id).is_equal(Endings.DEATH_FAMINE)
	var ending: Node = _app.show_screen("ending", true)
	await await_idle_frame()
	var words: String = _shown(ending)
	assert_str(words).contains(ShownFigures.none_reported())
	_never_shows(ending, [DENUNCIATION])


## The true meter keeps counting under the dark one: reported up past mid, its setback
## comes as it always would.
func test_the_setback_still_comes_for_a_dark_meter() -> void:
	var state: RunState = RunState.new(SEED)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots(), SetConfig.new())
	loop.start_set()
	state.famine = 30
	loop.player_books({"famine": 0})
	assert_bool(ShownFigures.is_true(RunView.new(loop.state), "famine")).is_false()
	loop.player_books({"famine": RunDefaults.METERS.famine.mid})
	assert_bool(loop.state.rationed).is_true()
	assert_bool(ShownFigures.is_true(RunView.new(loop.state), "famine")).is_false()
