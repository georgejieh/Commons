extends GdUnitTestSuite
## The landlord seat is easy to take and resented when taken from a neighbour: calling
## an open seat adds no Resentment, and grabbing a held one adds the data amount.

const SAVE_PATH: String = "user://test_bid_resentment/run.json"
const SEEDS: int = 60

var _app: DemoApp


func before_test() -> void:
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)


func after_test() -> void:
	Saves.run_service().delete()


func test_a_grab_adds_resentment_and_a_call_adds_none() -> void:
	var grabs: int = 0
	var calls: int = 0
	for run_seed: int in range(1, SEEDS + 1):
		_app.new_run(run_seed)
		var controller: RunController = _app.controller
		if controller.awaiting() != RunController.AWAIT_BID:
			continue
		var held: bool = controller.bid_holder() != Seats.NONE
		var before: int = controller.state_copy().resentment
		assert_int(controller.bid(true)).is_equal(RunController.OK)
		var rise: int = controller.state_copy().resentment - before
		assert_int(rise).is_equal(controller.grab_cost() if held else 0)
		grabs += 1 if held else 0
		calls += 0 if held else 1
	assert_int(grabs).is_greater(0)
	assert_int(calls).is_greater(0)
