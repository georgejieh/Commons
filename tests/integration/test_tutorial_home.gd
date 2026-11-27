extends GdUnitTestSuite
## Wang's slip at the table stands in the player's eye line (ADR 0026), on any
## monitor: centred between the two seats, its foot
## just over the trick, or over the claim sheet while that is up, and on none of the
## cards in play, the hand, the action column and its prompt, the ledger, the bar along
## the top, the seats or the Campaign tray. Where the claim sheet leaves no room over
## it, the slip stands beside it over Wang's own seat, still clear of all the rest.
## Held at every line the table steps show, at 1920x1080, 1280x800 and a maximized
## larger window, at every text size; the larger window plays with the Hint turned off,
## which the arrival never asks for.

const SETTINGS: Array[String] = [
	"content_note_seen", "reduced_motion", TextSize.SETTING, HintSetting.SETTING
]
## A 1440p monitor's maximized window, under a taskbar.
const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 800), Vector2i(2560, 1377)]
## The first step off the table: the Quota's report.
const LAST_TABLE_STEP: int = 16
const WAIT_MSEC: int = 60000

static var _save_path: String = TestFolder.of("test_tutorial_home") + "run.json"

var _app: DemoApp = null
var _saved: Dictionary[String, Variant] = {}
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	for key: String in SETTINGS:
		_saved[key] = Settings.value(key)
	Settings.set_value("content_note_seen", true)
	Settings.set_value("reduced_motion", true)
	Saves.use_run_path(_save_path)
	Saves.run_service().delete()
	Saves.profile_service().delete()


func after_test() -> void:
	get_tree().root.size = _was_size
	for key: String in _saved:
		Settings.set_value(key, _saved[key])
	Saves.run_service().delete()
	Saves.profile_service().delete()


func test_the_slip_stands_over_the_trick_at_every_size() -> void:
	for screen_size: Vector2i in SIZES:
		for level: int in TextSize.count():
			Settings.set_value(TextSize.SETTING, level)
			Settings.set_value(HintSetting.SETTING, screen_size != SIZES[-1])
			get_tree().root.size = screen_size
			await _walk("text size %d at %s" % [level, screen_size])


## Plays the table's steps, checking the slip at every line it shows there.
func _walk(where: String) -> void:
	if _app != null and is_instance_valid(_app):
		_app.free()
	_app = AppKit.make(self)
	await await_idle_frame()
	_app.arrival.start()
	var checked: Dictionary[String, bool] = {}
	var deadline: int = Time.get_ticks_msec() + WAIT_MSEC
	while Time.get_ticks_msec() < deadline:
		var director: TutorialDirector = _app.arrival.director
		if director == null or director.index() >= LAST_TABLE_STEP:
			break
		var table: TableScreen = _app.switcher.current() as TableScreen
		var key: String = director.line_key()
		if table != null and not key.is_empty() and not checked.has(key):
			# The layer stands the slip on its next frame.
			await await_idle_frame()
			await await_idle_frame()
			checked[key] = true
			_check(table, "%s %s" % [where, key])
		if director.phase() == TutorialDirector.Phase.PROMPT:
			await _answer(director.step())
		elif director.is_held():
			director.release()
		elif table != null:
			table.skip_events()
		await await_idle_frame()
	assert_int(_app.arrival.director.index()).override_failure_message(where).is_equal(
		LAST_TABLE_STEP
	)
	assert_int(checked.size()).override_failure_message(where).is_greater_equal(
		LAST_TABLE_STEP * 2 - 2
	)
	_app.arrival.end()


func _check(table: TableScreen, where: String) -> void:
	var slip: TutorialSlip = _app.arrival.layer.slip()
	assert_bool(slip.is_visible_in_tree()).override_failure_message(where).is_true()
	var rect: Rect2 = slip.get_global_rect()
	var screen: Rect2 = get_tree().root.get_visible_rect().grow(ClipCheck.SLACK)
	assert_bool(screen.encloses(rect)).override_failure_message("%s %s" % [where, rect]).is_true()
	var rules: CheatSheet = table.cheat_sheet
	if rules.visible:
		return
	var at: String = "%s: slip %s" % [where, rect]
	var kept: Dictionary[String, Rect2] = _kept(table)
	var need: NeedPanel = table.need_panel
	var sheet: Rect2 = need.get_global_rect()
	if need.visible and rect.end.y > sheet.position.y:
		# Beside the sheet, over Wang's seat, which is what it may cover.
		assert_float(rect.position.x).override_failure_message(at).is_greater(sheet.end.x)
		assert_float(rect.position.y).override_failure_message(at).is_equal_approx(
			TableTutorial.HOME_TOP, ClipCheck.SLACK
		)
		kept.erase("seat 1")
	else:
		assert_float(rect.get_center().x).override_failure_message(at).is_equal_approx(
			TableScreen.PLAY_CENTER, ClipCheck.SLACK
		)
		var pile: Control = table.pile
		var foot: float = sheet.position.y if need.visible else pile.get_global_rect().position.y
		# Close over the play: its foot within the gap of what it stands on.
		assert_float(rect.end.y).override_failure_message(at).is_between(
			foot - TableTutorial.HOME_GAP - ClipCheck.SLACK, foot
		)
	for piece: String in kept:
		var over: Rect2 = kept[piece]
		var clear: bool = not rect.intersects(over)
		assert_bool(clear).override_failure_message("%s on %s %s" % [at, piece, over]).is_true()


## Everything the slip must keep clear of at the table, by name.
func _kept(table: TableScreen) -> Dictionary[String, Rect2]:
	var kept: Dictionary[String, Rect2] = {}
	var pile: Control = table.pile
	kept["trick"] = pile.get_global_rect()
	var hand: Control = table.hand_view
	kept["hand"] = hand.get_global_rect()
	kept["actions"] = table.actions.get_global_rect()
	kept["prompt"] = table.actions.reading.get_global_rect()
	var ledger: Control = table.ledger
	kept["ledger"] = (ledger.get_parent() as Control).get_global_rect()
	var hud: Control = table.hud
	kept["bar"] = hud.get_global_rect()
	var seats: Dictionary[int, SeatPanel] = table.seats
	for seat: int in seats:
		kept["seat %d" % seat] = seats[seat].get_global_rect()
	var campaigns: TableCampaigns = table.campaigns
	if campaigns.tray.visible:
		kept["campaigns"] = campaigns.tray.get_global_rect()
	if table.need_panel.visible:
		kept["claim sheet"] = table.need_panel.get_global_rect()
	return kept


func _answer(step: TutorialStep) -> void:
	match step.action:
		TutorialStep.Action.BID_PASS, TutorialStep.Action.PASS:
			await TestInput.tap_key(self, KEY_SPACE)
		TutorialStep.Action.BID_CALL, TutorialStep.Action.PLAY, TutorialStep.Action.NEED:
			await TestInput.tap_key(self, KEY_ENTER)
		TutorialStep.Action.BUTTON:
			await TestInput.tap_key(self, KEY_R)
			await await_idle_frame()
			await TestInput.tap_key(self, KEY_ESCAPE)
