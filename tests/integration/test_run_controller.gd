extends GdUnitTestSuite
## The UI reaches a run only through RunController: the UI holds no core mutators, every
## UI action is a command, and the controller's signals carry every event the loop logs.

const FIXTURES: String = "res://tests/fixtures/ui_boundary/"
const SEED: int = 3701
const CONTROLLER: String = "res://game/run/run_controller.gd"
const LOOP: Script = preload("res://core/run/run_loop.gd")
## The loop's commands that are not named player_*.
const MOVES: Array[String] = ["open_shop", "next_set", "leave_store", "leave_reeducation"]


func test_ui_has_no_core_mutator_references() -> void:
	assert_array(UiBoundaryCheck.scan("res://ui")).is_empty()


## The bad fixtures each break the boundary once: one calls a loop command, one takes the
## loop through the controller's way in for tests and tools, and one takes it after a
## string with a hash in it, which is not a comment.
func test_checker_flags_a_mutator_and_ignores_comments() -> void:
	assert_array(UiBoundaryCheck.scan(FIXTURES + "bad")).has_size(3)
	assert_array(UiBoundaryCheck.scan(FIXTURES + "good")).is_empty()
	assert_array(UiBoundaryCheck.scan(FIXTURES + "missing")).has_size(1)
	# The seams tests and tools stock a shop and rebuild a run's modifiers through.
	assert_array(UiBoundaryCheck.scan(FIXTURES + "seams")).has_size(2)


## Every command the loop takes from the player is sent by the controller, and only
## through _act(), which saves the run and reports a refusal: read from both scripts, so
## a command added to the loop is checked without a list to keep.
func test_every_player_command_goes_through_act() -> void:
	var commands: Array[String] = []
	for method: Dictionary in LOOP.get_script_method_list():
		var method_name: String = method["name"]
		# A command answers with a reason; a query such as player_cards() does not.
		var reason: bool = str(method["return"]["class_name"]).ends_with("Reason")
		if reason and (method_name.begins_with("player_") or MOVES.has(method_name)):
			commands.append(method_name)
	assert_int(commands.size()).is_greater(MOVES.size())
	var source: String = FileAccess.get_file_as_string(CONTROLLER)
	var lines: PackedStringArray = source.split("\n")
	for command: String in commands:
		var sent: bool = false
		for line: String in lines:
			if not line.contains("_loop.%s" % command):
				continue
			var called: String = line.get_slice("_loop.%s" % command, 1)
			if not called.is_empty() and (called[0] == "_" or called[0].is_valid_identifier()):
				continue
			sent = true
			assert_bool(line.contains("_act(")).override_failure_message(line).is_true()
		assert_bool(sent).override_failure_message(command).is_true()


## The store is left only from the store, and reeducation only from reeducation.
func test_each_leave_command_is_refused_outside_its_own_phase() -> void:
	var controller: RunController = auto_free(RunController.new())
	controller.start_run(SEED, RunScript.bots())
	var script: ControllerScript = ControllerScript.new()
	while script.act(controller):
		pass
	assert_int(controller.finish_set()).is_equal(RunLoop.Reason.OK)
	assert_int(controller.awaiting()).is_equal(RunController.AWAIT_STORE)
	assert_int(controller.leave_reeducation()).is_equal(RunLoop.Reason.NOT_AWAITED)
	assert_int(controller.leave_store()).is_equal(RunLoop.Reason.OK)
	var loop: RunLoop = controller.run_loop()
	while script.act(controller):
		pass
	loop.state.reeducation_due = true
	assert_int(controller.finish_set()).is_equal(RunLoop.Reason.OK)
	assert_int(controller.awaiting()).is_equal(RunController.AWAIT_REEDUCATION)
	assert_int(controller.leave_store()).is_equal(RunLoop.Reason.NOT_AWAITED)
	assert_int(controller.leave_reeducation()).is_equal(RunLoop.Reason.OK)


func test_signals_carry_every_logged_event_through_a_set() -> void:
	var controller: RunController = auto_free(RunController.new())
	var seen: Array[RunEvent] = []
	controller.event_emitted.connect(func(event: RunEvent) -> void: seen.append(event))
	controller.start_run(SEED, RunScript.bots())
	var script: ControllerScript = ControllerScript.new()
	while script.act(controller):
		pass
	assert_int(controller.awaiting()).is_equal(RunLoop.Awaiting.SET_OVER)
	assert_array(seen).is_equal(controller.set_events())


## A Set's end and, after the store, the next Set's start both reach the view.
func test_signals_carry_events_across_a_set_boundary() -> void:
	var controller: RunController = auto_free(RunController.new())
	var types: Array[int] = []
	controller.event_emitted.connect(func(event: RunEvent) -> void: types.append(event.type))
	controller.start_run(SEED, RunScript.bots())
	var script: ControllerScript = ControllerScript.new()
	while script.act(controller):
		pass
	controller.finish_set()
	controller.leave_store()
	assert_int(types.count(RunEvent.Type.SET_ENDED)).is_equal(1)
	assert_int(types.count(RunEvent.Type.SET_STARTED)).is_equal(2)
	assert_int(types.rfind(RunEvent.Type.SET_STARTED)).is_greater(
		types.find(RunEvent.Type.SET_ENDED)
	)


func test_a_refused_command_signals_and_changes_nothing() -> void:
	var controller: RunController = auto_free(RunController.new())
	controller.start_run(SEED, RunScript.bots())
	var refused: Array[String] = []
	controller.command_refused.connect(
		func(command: String, _reason: int) -> void: refused.append(command)
	)
	var was: Dictionary = controller.state_copy().to_dict()
	assert_int(controller.declare_need(5)).is_equal(RunLoop.Reason.NOT_AWAITED)
	assert_array(refused).contains_exactly(["declare_need"])
	assert_dict(controller.state_copy().to_dict()).is_equal(was)


func test_state_copy_is_not_the_run_state() -> void:
	var controller: RunController = auto_free(RunController.new())
	controller.start_run(SEED, RunScript.bots())
	var copy: RunState = controller.state_copy()
	copy.coupons += 100
	assert_int(controller.state_copy().coupons).is_equal(copy.coupons - 100)


## A whole demo Year through the controller alone: three Sets, two store visits that
## buy what they can afford, and the run's end.
func test_a_whole_year_plays_through_the_controller() -> void:
	var controller: RunController = auto_free(RunController.new())
	var sets: SetConfig = SetConfig.new(load("res://data/run/demo_sets.tres"))
	controller.start_run(SEED, RunScript.bots(), sets, null, 20)
	var started: Array[int] = []
	controller.event_emitted.connect(
		func(event: RunEvent) -> void:
			if event.type == RunEvent.Type.SET_STARTED:
				started.append(event.value)
	)
	ControllerScript.new().play_run(controller)
	assert_int(controller.awaiting()).is_equal(RunController.AWAIT_RUN_OVER)
	assert_array(started).contains_exactly([1, 2])
	assert_bool(controller.state_copy().inventory.cadres.is_empty()).is_false()


## A save taken in the store resumes there with the same stock and the purchase kept.
func test_a_save_in_the_store_resumes_with_the_same_stock() -> void:
	var service: SaveService = SaveService.for_run(TestFolder.of("test_controller") + "run.json")
	service.delete()
	var controller: RunController = auto_free(RunController.new())
	controller.start_run(SEED, RunScript.bots(), SetConfig.new(), service, 20)
	var script: ControllerScript = ControllerScript.new()
	while script.act(controller):
		pass
	controller.finish_set()
	assert_int(controller.awaiting()).is_equal(RunController.AWAIT_STORE)
	assert_int(controller.buy(0)).is_equal(RunController.OK)
	var stock: Array[String] = controller.store.store_stock()
	var coupons: int = controller.state_copy().coupons
	var resumed: RunController = auto_free(RunController.new())
	assert_bool(resumed.resume_saved(service, RunScript.bots(), SetConfig.new())).is_true()
	assert_int(resumed.awaiting()).is_equal(RunController.AWAIT_STORE)
	assert_array(resumed.store.store_stock()).is_equal(stock)
	assert_int(resumed.state_copy().coupons).is_equal(coupons)
	# A purchase after the resume saves too, and a second resume keeps it.
	var slot: int = resumed.store.store_stock().find(RunShop.SOLD) + 1
	var bought: Array[String] = resumed.state_copy().inventory.cadres
	if resumed.store.can_buy(slot):
		resumed.buy(slot)
		bought = resumed.state_copy().inventory.cadres
	var again: RunController = auto_free(RunController.new())
	assert_bool(again.resume_saved(service, RunScript.bots(), SetConfig.new())).is_true()
	assert_int(service.load_save().status).is_equal(SaveLoad.Status.OK)
	assert_array(again.state_copy().inventory.cadres).is_equal(bought)
	service.delete()


## A run resumed mid-round hands the view only events it has not read from the log.
func test_a_resumed_run_never_repeats_an_event() -> void:
	var service: SaveService = SaveService.for_run(TestFolder.of("test_controller") + "run.json")
	service.delete()
	var controller: RunController = auto_free(RunController.new())
	controller.start_run(SEED, RunScript.bots(), SetConfig.new(), service)
	var script: ControllerScript = ControllerScript.new()
	while controller.awaiting() != RunController.AWAIT_NEED:
		if not script.act(controller):
			break
	if controller.awaiting() != RunController.AWAIT_NEED:
		service.delete()
		return
	var resumed: RunController = auto_free(RunController.new())
	assert_bool(resumed.resume_saved(service, RunScript.bots(), SetConfig.new())).is_true()
	var known: Array[RunEvent] = resumed.set_events()
	var heard: Array[RunEvent] = []
	resumed.event_emitted.connect(func(event: RunEvent) -> void: heard.append(event))
	resumed.declare_need(ControllerScript.NEED)
	for event: RunEvent in heard:
		assert_bool(known.has(event)).is_false()
	service.delete()
