extends GdUnitTestSuite
## The arrival's words come after what they describe (ADR 0026): played at the table's own pace
## with motion on, every line Wang says at the table, a prompt or the line after the player's
## action, shows only once the villagers' answer has been played out and the cards on top of
## the trick have landed. The answer ends where the table waits on the player again, or where a
## new deal begins.

const SETTINGS: Array[String] = ["content_note_seen", "reduced_motion", "table_pace"]
## The fast pace, so the walk takes less time; every wait still follows it.
const FAST: int = 2
## The first step off the table: the Quota's report.
const LAST_TABLE_STEP: int = 16
const WAIT_MSEC: int = 240000

static var _save_path: String = TestFolder.of("test_tutorial_timing") + "run.json"

var _app: DemoApp = null
var _saved: Dictionary[String, Variant] = {}
## The event the table played last.
var _last: RunEvent = null
var _watched: TableScreen = null


func before_test() -> void:
	for key: String in SETTINGS:
		_saved[key] = Settings.value(key)
	Settings.set_value("content_note_seen", true)
	Settings.set_value("reduced_motion", false)
	Settings.set_value("table_pace", FAST)
	Saves.use_run_path(_save_path)
	Saves.run_service().delete()
	Saves.profile_service().delete()


func after_test() -> void:
	for key: String in _saved:
		Settings.set_value(key, _saved[key])
	Saves.run_service().delete()
	Saves.profile_service().delete()


func test_every_line_at_the_table_follows_what_it_describes() -> void:
	_app = AppKit.make(self)
	await await_idle_frame()
	_app.arrival.start()
	var shown: String = ""
	var checked: int = 0
	var deadline: int = Time.get_ticks_msec() + WAIT_MSEC
	while Time.get_ticks_msec() < deadline:
		var director: TutorialDirector = _app.arrival.director
		if director == null or director.index() >= LAST_TABLE_STEP:
			break
		var table: TableScreen = _app.switcher.current() as TableScreen
		_watch(table)
		var key: String = director.line_key()
		if key != shown and not key.is_empty() and table != null:
			shown = key
			checked += 1
			var early: String = _unfinished(table)
			assert_str(early).override_failure_message("%s: %s" % [key, early]).is_empty()
		if director.phase() == TutorialDirector.Phase.PROMPT and key == shown:
			await _answer(director.step())
		elif director.is_held() and key == shown:
			director.release()
		await await_idle_frame()
	assert_int(_app.arrival.director.index()).is_equal(LAST_TABLE_STEP)
	# Every table step's prompt and every line after a villager's answer was seen.
	assert_int(checked).is_greater_equal(LAST_TABLE_STEP * 2 - 2)


## What of the villagers' answer is still to be seen, or "" when it has all played out.
func _unfinished(table: TableScreen) -> String:
	var player: EventPlayer = table.player
	var new_deal: bool = _last != null and _last.type == RunEvent.Type.DEALT
	if not player.is_idle() and not new_deal:
		var queue: Array[RunEvent] = player.get("_queue")
		return "%d events still to play" % queue.size()
	var pile: TrickPile = table.pile
	for view: CardView in pile.top_views():
		if not view.scale.is_equal_approx(Vector2.ONE * TrickPile.PLAY_SCALE):
			return "the top play's cards are still in the air"
	return ""


func _watch(table: TableScreen) -> void:
	if table == null or table == _watched:
		return
	_watched = table
	var player: EventPlayer = table.player
	player.played.connect(func(event: RunEvent) -> void: _last = event)


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
