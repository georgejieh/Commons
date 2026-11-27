extends GdUnitTestSuite
## ADR 0022's books command: figures reported from outside the game are taken as
## official, never refused for being untrue. Each figure raised and lowered, the clamp,
## the norm and price proportions against the data, the caps, and a malformed command
## refused. Saves, replays and the file's raise are in test_books_saves.gd.

const SEED: int = 4719
const BOOKS: BooksParams = preload("res://data/run/books.tres")


func _loop(coupons: int = 10, seed_value: int = SEED) -> RunLoop:
	var state: RunState = RunState.new(seed_value)
	state.coupons = coupons
	var loop: RunLoop = RunLoop.new(state, RunScript.bots(), SetConfig.new())
	loop.start_set()
	return loop


## A loop past its first Quota, waiting at the Quota's end.
func _at_set_over(coupons: int = 10) -> RunLoop:
	var loop: RunLoop = _loop(coupons)
	RunScript.new().play_until_set_over(loop)
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.SET_OVER)
	return loop


func _corrections(loop: RunLoop) -> Array[RunEvent]:
	var found: Array[RunEvent] = []
	for event: RunEvent in loop.events():
		if event.type == RunEvent.Type.BOOKS_CORRECTED:
			found.append(event)
	return found


func test_a_raised_coupon_count_becomes_the_plan() -> void:
	var loop: RunLoop = _loop(10)
	assert_int(loop.player_books({"coupons": 25})).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.coupons).is_equal(25)
	# Reported over true, 2.5 times: every later target and every price rise 150%.
	assert_int(loop.state.books.norm_percent).is_equal(150)
	assert_int(loop.state.books.price_percent).is_equal(150)
	assert_int(loop.state.books.corrections).is_equal(1)
	var event: RunEvent = _corrections(loop)[0]
	assert_str(event.text).is_equal("coupons")
	assert_array(event.correction.true_values).contains_exactly([10.0])
	assert_array(event.correction.reported).contains_exactly([25.0])
	assert_int(event.correction.norm_added).is_equal(150)
	assert_int(event.correction.price_added).is_equal(150)


func test_the_raised_norm_waits_for_the_next_quota() -> void:
	var honest: RunLoop = _loop(10)
	var cheated: RunLoop = _loop(10)
	var was: float = cheated.target()
	cheated.player_books({"coupons": 20})
	assert_float(cheated.target()).is_equal(was)
	for loop: RunLoop in [honest, cheated]:
		RunScript.new().play_until_set_over(loop)
		assert_int(RunScript.next_set(loop)).is_equal(RunLoop.Reason.OK)
	assert_float(cheated.target()).is_equal_approx(honest.target() * 2.0, 0.001)


func test_coupons_from_none_count_from_one() -> void:
	var loop: RunLoop = _loop(0)
	loop.player_books({"coupons": 3})
	assert_int(loop.state.books.norm_percent).is_equal(200)
	assert_int(loop.state.books.price_percent).is_equal(200)


func test_lowered_coupons_become_official_and_nothing_else() -> void:
	var loop: RunLoop = _loop(10)
	loop.player_books({"coupons": 4})
	assert_int(loop.state.coupons).is_equal(4)
	assert_int(loop.state.books.norm_percent).is_equal(0)
	assert_int(loop.state.books.price_percent).is_equal(0)
	assert_array(loop.state.books.dark).is_empty()


func test_raised_progress_raises_the_norm_by_its_share_of_the_target() -> void:
	var loop: RunLoop = _loop()
	var target: float = loop.target()
	loop.player_books({"progress": target / 2.0})
	assert_float(loop.state.set_progress).is_equal(target / 2.0)
	assert_int(loop.state.books.norm_percent).is_equal(50)
	assert_int(loop.state.books.price_percent).is_equal(0)


func test_lowered_progress_becomes_official() -> void:
	var loop: RunLoop = _loop()
	loop.state.set_progress = 600.0
	loop.player_books({"progress": RunState.float_text(100.0)})
	assert_float(loop.state.set_progress).is_equal(100.0)
	assert_int(loop.state.books.norm_percent).is_equal(0)


func test_a_lowered_meter_goes_dark_and_keeps_counting() -> void:
	for meter: String in ["famine", "denunciation", "resentment"]:
		var loop: RunLoop = _loop()
		_set_figure(loop.state, meter, 30)
		loop.player_books({meter: 0})
		assert_int(_figure(loop.state, meter)).override_failure_message(meter).is_equal(30)
		assert_array(loop.state.books.dark).contains_exactly([meter])
		var event: RunEvent = _corrections(loop)[0]
		assert_array(event.correction.dark).contains_exactly([meter])
		# Lowered again, it is already dark and stays so once.
		loop.player_books({meter: 1})
		assert_array(loop.state.books.dark).contains_exactly([meter])


func test_a_raised_meter_brings_its_setback() -> void:
	var loop: RunLoop = _loop()
	var mid: int = RunDefaults.METERS.famine.mid
	loop.player_books({"famine": mid, "denunciation": RunDefaults.METERS.denunciation.mid})
	assert_int(loop.state.famine).is_equal(mid)
	assert_bool(loop.state.rationed).is_true()
	assert_bool(loop.state.reeducation_due).is_true()
	assert_array(loop.state.books.dark).is_empty()
	var setbacks: int = 0
	for event: RunEvent in loop.events():
		if event.type == RunEvent.Type.SETBACK and event.value == 1:
			setbacks += 1
	assert_int(setbacks).is_equal(2)


func test_raised_resentment_becomes_official() -> void:
	var loop: RunLoop = _loop()
	loop.player_books({"resentment": 40})
	assert_int(loop.state.resentment).is_equal(40)
	var causes: Array[String] = []
	for event: RunEvent in loop.events():
		if event.type == RunEvent.Type.RESENTMENT:
			causes.append(event.text)
	assert_array(causes).contains([RunCorrections.CAUSE])


func test_the_norm_raised_is_accepted_and_lowered_goes_dark() -> void:
	var loop: RunLoop = _loop()
	var was: float = loop.target()
	loop.player_books({"norm": 5})
	assert_int(loop.state.norm_steps).is_equal(5)
	assert_float(loop.target()).is_greater(was)
	loop.player_books({"norm": 1})
	assert_int(loop.state.norm_steps).is_equal(5)
	assert_array(loop.state.books.dark).contains_exactly(["norm"])


func test_a_raised_meter_at_its_death_ends_the_run_away_from_the_table() -> void:
	var loop: RunLoop = _at_set_over()
	loop.player_books({"famine": RunDefaults.METERS.famine.death})
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.RUN_OVER)
	assert_int(loop.state.phase).is_equal(RunFlow.State.RUN_END)


func test_figures_past_their_fields_are_clamped() -> void:
	var loop: RunLoop = _loop(10)
	var figures: Dictionary = {
		"coupons": 1_000_000_000_000,
		"famine": 500,
		"denunciation": -40,
		"resentment": 1e30,
		"norm": 99999,
		"progress": 1e308 * 10.0,
	}
	assert_int(loop.player_books(figures)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.coupons).is_equal(BOOKS.coupons_max)
	assert_int(loop.state.famine).is_equal(RunDefaults.PARAMS.meter_max)
	assert_int(loop.state.denunciation).is_equal(0)
	assert_int(loop.state.resentment).is_equal(RunDefaults.RESENTMENT.cap)
	assert_int(loop.state.norm_steps).is_equal(BOOKS.norm_steps_max)
	assert_float(loop.state.set_progress).is_equal(Scorer.MAX_SCORE)
	var saved: Dictionary = loop.record.commands[-1]["figures"]
	assert_int(int(saved["coupons"])).is_equal(BOOKS.coupons_max)


func test_the_norm_and_prices_stop_at_their_caps() -> void:
	var loop: RunLoop = _loop(1)
	loop.player_books({"coupons": BOOKS.coupons_max})
	assert_int(loop.state.books.norm_percent).is_equal(BOOKS.norm_cap_percent)
	assert_int(loop.state.books.price_percent).is_equal(BOOKS.price_cap_percent)
	loop.player_books({"coupons": 0})
	loop.player_books({"coupons": 50})
	assert_int(loop.state.books.norm_percent).is_equal(BOOKS.norm_cap_percent)
	assert_int(loop.state.books.price_percent).is_equal(BOOKS.price_cap_percent)


func test_corrections_compound() -> void:
	var loop: RunLoop = _loop(10)
	loop.player_books({"coupons": 20})
	loop.player_books({"coupons": 40})
	# Twice, then twice again: four times, 300% over the first.
	assert_int(loop.state.books.norm_percent).is_equal(300)
	assert_int(loop.state.books.price_percent).is_equal(300)
	assert_int(loop.state.books.corrections).is_equal(2)


func test_both_shops_prices_rise_by_the_coupons_proportion() -> void:
	var loop: RunLoop = _at_set_over(10)
	assert_int(loop.open_shop()).is_equal(RunLoop.Reason.OK)
	var store: int = loop.visit.shop.price(0)
	var market: int = loop.visit.market.price(0)
	var reroll: int = loop.visit.shop.reroll_price()
	var upgrades: PlotUpgradeParams = RunDefaults.PLOT_UPGRADES
	var upgrade: int = PlotUpgrades.price(PlotUpgrades.SWAPS, upgrades, loop.state)
	loop.player_books({"coupons": loop.state.coupons * 2})
	assert_int(loop.visit.shop.price(0)).is_equal(store * 2)
	assert_int(loop.visit.market.price(0)).is_equal(market * 2)
	assert_int(loop.visit.shop.reroll_price()).is_equal(reroll * 2)
	var raised: int = PlotUpgrades.price(PlotUpgrades.SWAPS, upgrades, loop.state)
	assert_int(raised).is_equal(upgrade * 2)


func test_malformed_figures_are_refused_and_change_nothing() -> void:
	for bad: Dictionary in [
		{"grain": 4}, {"coupons": "lots"}, {"coupons": [3]}, {"progress": "nothex"}, {3: 4}
	]:
		var loop: RunLoop = _loop(10)
		var was: String = JSON.stringify(loop.state.to_dict())
		var commands: int = loop.record.commands.size()
		assert_int(loop.player_books(bad)).is_equal(RunLoop.Reason.ILLEGAL)
		assert_str(JSON.stringify(loop.state.to_dict())).is_equal(was)
		assert_int(loop.record.commands.size()).is_equal(commands)


func test_true_figures_change_nothing_but_are_still_recorded() -> void:
	var loop: RunLoop = _loop(10)
	assert_int(loop.player_books({"coupons": 10})).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.books.corrections).is_equal(0)
	assert_bool(_corrections(loop)[0].correction.is_empty()).is_true()


func test_refused_while_the_loop_waits_on_nothing_from_the_player() -> void:
	var loop: RunLoop = _at_set_over()
	loop.player_books({"famine": RunDefaults.METERS.famine.death})
	assert_int(loop.player_books({"coupons": 99})).is_equal(RunLoop.Reason.NOT_AWAITED)


func _figure(state: RunState, figure: String) -> int:
	match figure:
		"famine":
			return state.famine
		"denunciation":
			return state.denunciation
	return state.resentment


func _set_figure(state: RunState, figure: String, value: int) -> void:
	match figure:
		"famine":
			state.famine = value
		"denunciation":
			state.denunciation = value
		_:
			state.resentment = value
