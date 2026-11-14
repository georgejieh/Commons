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


func test_grabbing_the_seat_back_is_charged_too() -> void:
	var grab_backs: int = 0
	for run_seed: int in range(1, 4 * SEEDS + 1):
		# In Year 3's first round the player bids first, so a villager can grab after.
		var state: RunState = RunState.new(run_seed)
		state.year = 3
		var loop: RunLoop = RunLoop.new(state, RunScript.bots(), SetConfig.new())
		loop.start_set()
		if loop.awaiting() != RunLoop.Awaiting.PLAYER_BID or loop.bid_holder() != Seats.NONE:
			continue
		loop.player_bid(true)
		assert_int(state.resentment).is_equal(0)
		# Asked again: a villager grabbed the seat the player called.
		if loop.awaiting() != RunLoop.Awaiting.PLAYER_BID:
			continue
		assert_int(loop.bid_holder()).is_not_equal(Seats.NONE)
		assert_int(loop.player_bid(true)).is_equal(RunLoop.Reason.OK)
		assert_int(state.resentment).is_equal(RunLoop.DEFAULT_RESENTMENT.grab)
		# It is logged before the round it starts, so the villagers' grudge counts it.
		var types: Array = loop.events().map(func(event: RunEvent) -> int: return event.type)
		assert_int(types.find(RunEvent.Type.RESENTMENT)).is_less(
			types.find(RunEvent.Type.LANDLORD_CHOSEN)
		)
		grab_backs += 1
	assert_int(grab_backs).is_greater(0)


func test_the_first_bidder_rotates_with_the_year() -> void:
	for year: int in range(1, 4):
		var state: RunState = RunState.new(77)
		state.year = year
		var loop: RunLoop = RunLoop.new(state, RunScript.bots(), SetConfig.new())
		loop.start_set()
		var first: int = (year + state.set_index + state.round_index) % Seats.COUNT
		var bids: Array[RunEvent] = loop.events().filter(
			func(event: RunEvent) -> bool: return event.type == RunEvent.Type.BID
		)
		if first == RunLoop.PLAYER:
			assert_array(bids).is_empty()
			assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.PLAYER_BID)
		else:
			assert_int(bids[0].seat).is_equal(first)
