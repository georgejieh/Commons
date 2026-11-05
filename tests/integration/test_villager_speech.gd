extends GdUnitTestSuite
## Villagers at the table (P3B.8): speech lines come from data with valid moods and
## string keys, a Set played through the table speaks one cards-left line per
## announcement, and the dossier shows what was seen.

const SEED: int = 4301
const SAVE_PATH: String = "user://test_villager_speech/run.json"
const BOOK: SpeechBook = preload("res://data/ui/speech_book.tres")

var _app: DemoApp
var _announced: Dictionary[int, int] = {}
var _spoken: Dictionary[int, int] = {}


func before_test() -> void:
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)
	_app.new_run(SEED)


func after_test() -> void:
	Saves.run_service().delete()


func test_every_event_has_lines_with_keys_and_known_moods() -> void:
	for event: String in SpeechBook.EVENTS:
		assert_array(BOOK.lines_for(event)).is_not_empty()
	for line: SpeechLine in BOOK.lines:
		assert_array(SpeechBook.EVENTS).contains([line.event])
		assert_str(tr(line.text_key)).is_not_equal(line.text_key)
		if not line.mood.is_empty():
			assert_array(SpeechBook.MOODS).contains([line.mood])


func test_the_same_salt_picks_the_same_line() -> void:
	for salt: int in 20:
		assert_object(BOOK.pick("pass", salt)).is_same(BOOK.pick("pass", salt))


func test_each_announcement_is_spoken_once_and_the_dossier_fills() -> void:
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	var speech: TableSpeech = table.get("_speech")
	speech.spoke.connect(_on_spoke)
	_app.controller.event_emitted.connect(_on_event)
	await _play_set(table)
	_app.controller.event_emitted.disconnect(_on_event)
	var total: int = 0
	for seat: int in range(1, Seats.COUNT):
		assert_int(_spoken.get(seat, 0)).is_equal(_announced.get(seat, 0))
		total += _announced.get(seat, 0)
	assert_int(total).is_greater(0)
	var dossier: DossierScreen = _app.show_screen("dossier")
	await await_idle_frame()
	var state: RunState = _app.controller.state_copy()
	for seat: int in range(1, Seats.COUNT):
		var family: String = state.table[seat]
		var bids: int = state.observations.count(family, Observations.Kind.BIDS)
		var called: int = state.observations.count(family, Observations.Kind.CALLS)
		var calls: String = tr("dossier.calls").format({"called": called, "bids": bids})
		assert_array(Array(dossier.entries(seat))).contains([calls])
	_app.back()
	await await_idle_frame()
	assert_str(_app.switcher.current_id()).is_not_equal("dossier")


func _on_event(event: RunEvent) -> void:
	if event.type == RunEvent.Type.ROUND:
		var played: RoundEvent = event.round_event
		if played.type == RoundEvent.Type.ANNOUNCED and played.seat != 0:
			_announced[played.seat] = _announced.get(played.seat, 0) + 1


func _on_spoke(seat: int, event: String, _line: SpeechLine) -> void:
	if event == "cards_left":
		_spoken[seat] = _spoken.get(seat, 0) + 1


func _play_set(table: TableScreen) -> void:
	var driver: ControllerScript = ControllerScript.new()
	for _turn: int in 600:
		if _app.switcher.current_id() != "table":
			return
		table.skip_events()
		if _app.switcher.current_id() != "table":
			return
		match _app.controller.awaiting():
			RunController.AWAIT_BID:
				table.actions().decline.pressed.emit()
			RunController.AWAIT_NEED:
				table.need_panel().declared.emit(ControllerScript.NEED)
			RunController.AWAIT_PLAY:
				var ids: Array[int] = driver.choose_play(_app.controller)
				if ids.is_empty():
					table.actions().pass_turn.pressed.emit()
				else:
					for card_id: int in ids:
						_app.hand.toggle(card_id)
					table.actions().play.pressed.emit()
		await await_idle_frame()
