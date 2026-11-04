extends GdUnitTestSuite
## The UI reaches a run only through RunController: the UI holds no core mutators, every
## UI action is a command, and the controller's signals carry every event the loop logs.

const FIXTURES: String = "res://tests/fixtures/ui_boundary/"
const SEED: int = 3701
const UI_ACTIONS: Array[String] = [
	"bid", "swap", "play", "pass", "declare_need", "finish_set", "buy", "reroll", "leave_store"
]


func test_ui_has_no_core_mutator_references() -> void:
	assert_array(UiBoundaryCheck.scan("res://ui")).is_empty()


func test_checker_flags_a_mutator_and_ignores_comments() -> void:
	assert_array(UiBoundaryCheck.scan(FIXTURES + "bad")).has_size(1)
	assert_array(UiBoundaryCheck.scan(FIXTURES + "good")).is_empty()
	assert_array(UiBoundaryCheck.scan(FIXTURES + "missing")).has_size(1)


func test_every_ui_action_is_a_controller_command() -> void:
	var controller: RunController = auto_free(RunController.new())
	assert_array(RunController.COMMANDS).contains_exactly(UI_ACTIONS)
	for command: String in RunController.COMMANDS:
		var method: String = "pass_turn" if command == "pass" else command
		assert_bool(controller.has_method(method)).override_failure_message(command).is_true()


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
	var before: Dictionary = controller.state_copy().to_dict()
	assert_int(controller.declare_need(5)).is_equal(RunLoop.Reason.NOT_AWAITED)
	assert_array(refused).contains_exactly(["declare_need"])
	assert_dict(controller.state_copy().to_dict()).is_equal(before)


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
	var service: SaveService = SaveService.for_run("user://test_controller/run.json")
	service.delete()
	var controller: RunController = auto_free(RunController.new())
	controller.start_run(SEED, RunScript.bots(), SetConfig.new(), service, 20)
	var script: ControllerScript = ControllerScript.new()
	while script.act(controller):
		pass
	controller.finish_set()
	assert_int(controller.awaiting()).is_equal(RunController.AWAIT_STORE)
	assert_int(controller.buy(0)).is_equal(RunController.OK)
	var stock: Array[String] = controller.store_stock()
	var coupons: int = controller.state_copy().coupons
	var resumed: RunController = auto_free(RunController.new())
	assert_bool(resumed.resume_saved(service, RunScript.bots(), SetConfig.new())).is_true()
	assert_int(resumed.awaiting()).is_equal(RunController.AWAIT_STORE)
	assert_array(resumed.store_stock()).is_equal(stock)
	assert_int(resumed.state_copy().coupons).is_equal(coupons)
	service.delete()
