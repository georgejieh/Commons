extends GdUnitTestSuite
## Sitting out a trick (P5.2a, the owner's request). When the player must follow and
## nothing they hold is legal, Sit out stands beside Pass; pressed, or pressed by its key,
## it passes for them through the ordinary pass command until the trick ends, the table's
## step shortened meanwhile, and it never reaches into the next trick. It is never offered
## while any play is legal, a bomb or rocket included, nor during the arrival.

const SAVE_PATH: String = "user://test_sit_out/run.json"
const SEEDS: Array[int] = [3, 5, 7, 11, 13, 17, 19, 23]
const WAIT_SECONDS: float = 40.0

var _app: DemoApp


func before_test() -> void:
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	Settings.set_value("reduced_motion", true)
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)


func after_test() -> void:
	Settings.set_value("reduced_motion", false)
	Saves.run_service().delete()


## Plays the run forward until the player must follow with an answer (answer true) or with
## none (false). False when no seed reaches it.
func _to_turn(answer: bool) -> bool:
	var driver: ControllerScript = ControllerScript.new()
	for seed_value: int in SEEDS:
		_app.new_run(seed_value)
		for _step: int in 400:
			var awaiting: int = _app.controller.awaiting()
			var view: SeatView = _app.controller.seat_view()
			var following: bool = view != null and view.public.current_play != null
			if awaiting == RunController.AWAIT_PLAY and following:
				var legal: bool = not _app.controller.legal_moves().is_empty()
				if legal == answer and _app.controller.pass_refusal().is_empty():
					return true
			if awaiting == RunController.AWAIT_SET_OVER or not driver.act(_app.controller):
				break
	return false


func _open_table() -> TableScreen:
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	await _until(table.get("_player").is_idle)
	return table


func test_it_is_offered_only_with_nothing_but_a_pass() -> void:
	assert_bool(_to_turn(false)).is_true()
	var table: TableScreen = await _open_table()
	assert_bool(table.actions().sit_out.visible).is_true()
	assert_str(table.actions().sit_out.tooltip_text).is_equal(tr("action.sit_out_tip"))
	# With any legal play in hand, a bomb or rocket among them, it is not offered.
	assert_bool(_to_turn(true)).is_true()
	table = await _open_table()
	assert_bool(table.actions().sit_out.visible).is_false()
	var sit_out: SitOut = table.get("_sit_out")
	assert_bool(sit_out.offered()).is_false()


func test_sitting_out_passes_to_the_tricks_end_at_a_faster_step() -> void:
	assert_bool(_to_turn(false)).is_true()
	var table: TableScreen = await _open_table()
	var player: EventPlayer = table.get("_player")
	var sit_out: SitOut = table.get("_sit_out")
	var normal: float = player.step
	var seen: Dictionary = {"passes": 0, "plays": 0, "ended": false, "fast": true}
	player.played.connect(_count.bind(seen, sit_out, player, normal))
	table.actions().sit_out.pressed.emit()
	assert_bool(sit_out.is_active()).is_true()
	assert_float(player.step).is_equal_approx(normal * TableMotion.PRESETS.sit_out_scale, 0.0001)
	assert_str(table.actions().reading.text).is_equal(tr("table.sitting_out"))
	await _until(func() -> bool: return bool(seen["ended"]) or not sit_out.is_active())
	await _until(player.is_idle)
	# Every turn of the player's in that trick was a pass, through the pass command.
	assert_int(int(seen["passes"])).is_greater(0)
	assert_int(int(seen["plays"])).is_equal(0)
	assert_bool(bool(seen["fast"])).is_true()
	# It ended with the trick, the step is back, and it does not reach the next trick.
	assert_bool(sit_out.is_active()).is_false()
	assert_float(player.step).is_equal_approx(normal, 0.0001)


## The key bound to sitting out presses the same button.
func test_the_key_sits_out_as_the_button_does() -> void:
	assert_bool(_to_turn(false)).is_true()
	var table: TableScreen = await _open_table()
	var sit_out: SitOut = table.get("_sit_out")
	assert_bool(KeyBindings.ACTIONS.has("commons_sit_out")).is_true()
	assert_bool(InputMap.has_action("commons_sit_out")).is_true()
	var event: InputEventAction = InputEventAction.new()
	event.action = "commons_sit_out"
	event.pressed = true
	table.call("_unhandled_input", event)
	assert_bool(sit_out.is_active()).is_true()


func test_it_is_never_offered_during_the_arrival() -> void:
	assert_bool(_to_turn(false)).is_true()
	var table: TableScreen = await _open_table()
	var sit_out: SitOut = table.get("_sit_out")
	sit_out.set("_blocked", func() -> bool: return true)
	assert_bool(sit_out.offered()).is_false()


func _count(
	event: RunEvent, seen: Dictionary, sit_out: SitOut, player: EventPlayer, normal: float
) -> void:
	if bool(seen["ended"]) or event.round_event == null:
		return
	var round_event: RoundEvent = event.round_event
	if (
		round_event.type == RoundEvent.Type.TRICK_WON
		or round_event.type == RoundEvent.Type.ROUND_ENDED
	):
		seen["ended"] = true
		return
	if (
		sit_out.is_active()
		and not is_equal_approx(player.step, normal * TableMotion.PRESETS.sit_out_scale)
	):
		seen["fast"] = false
	if round_event.seat != 0:
		return
	if round_event.type == RoundEvent.Type.PASSED:
		seen["passes"] = int(seen["passes"]) + 1
	elif round_event.type == RoundEvent.Type.PLAYED:
		seen["plays"] = int(seen["plays"]) + 1


func _until(done: Callable) -> void:
	var waited: float = 0.0
	while not bool(done.call()) and waited < WAIT_SECONDS:
		await get_tree().process_frame
		waited += get_process_delta_time()
