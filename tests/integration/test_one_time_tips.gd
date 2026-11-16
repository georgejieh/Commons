extends GdUnitTestSuite
## The one-time tooltips (ADR 0026): each shows once per profile, the first time its
## subject comes up in a full run, and never in the demo or the arrival. Dismissing one
## writes it to the profile's seen list, so it stays dismissed across runs and restarts.

const SAVE_PATH: String = "user://test_one_time_tips/run.json"
const SEED: int = 4242

var _app: DemoApp = null


func before_test() -> void:
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	Saves.profile_service().delete()
	ProfileSeen.mark(Saves.profile_service(), ProfileSeen.TUTORIAL)
	await _launch()


func after_test() -> void:
	Saves.run_service().delete()
	Saves.profile_service().delete()


## A fresh app, as after a restart.
func _launch() -> void:
	if _app != null and is_instance_valid(_app):
		_app.free()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)
	await await_idle_frame()


func _loop() -> RunLoop:
	return _app.controller.get("_loop")


## The tooltip slip a screen shows, or null.
func _tip(screen: Node) -> TipSlip:
	await await_idle_frame()
	await await_idle_frame()
	var found: Array[Node] = screen.find_children("*", "TipSlip", true, false)
	return null if found.is_empty() else found[0] as TipSlip


## Opens the Quota page of a fresh full run, with a debuff on its ladder.
func _full_quota_page(memory: bool) -> Node:
	assert_bool(_app.new_run(SEED, true)).is_true()
	var state: RunState = _loop().state
	if state.debuff_ladder.size() > 1:
		state.debuff_ladder[1] = RunLoop.DEFAULT_POOL.debuffs[0].id
	if memory:
		state.memory.counts[state.table[1]] = PackedFloat64Array([1.0, 0.0, 0.0, 0.0])
	return _app.show_screen("set_intro", true)


func _dismiss_all(slip: TipSlip) -> Array[String]:
	var seen: Array[String] = []
	await await_idle_frame()
	while slip != null and is_instance_valid(slip) and not slip.shown().is_empty():
		seen.append(slip.shown())
		assert_object(get_viewport().gui_get_focus_owner()).is_same(slip.got_it_button())
		slip.got_it_button().pressed.emit()
		await await_idle_frame()
	return seen


func test_debuffs_and_memory_show_once_across_two_full_runs_and_a_restart() -> void:
	var first: TipSlip = await _tip(_full_quota_page(false))
	assert_array(await _dismiss_all(first)).is_equal(["tip.debuffs"])
	var second: TipSlip = await _tip(_full_quota_page(true))
	assert_array(await _dismiss_all(second)).is_equal(["tip.memory"])
	await _launch()
	assert_object(await _tip(_full_quota_page(true))).is_null()
	var seen: Array[String] = Profile.read(Saves.profile_service()).seen
	assert_array(seen).contains_exactly(["tutorial", "tip.debuffs", "tip.memory"])


func test_the_plot_tip_shows_once_per_profile() -> void:
	assert_bool(_app.new_run(SEED, true)).is_true()
	var host: Control = _app.show_screen("title", true)
	var tips: Array[String] = ["tip.plot"]
	var slip: TipSlip = TipSlip.offer(host, _app, tips)
	assert_object(slip).is_not_null()
	assert_array(await _dismiss_all(slip)).is_equal(["tip.plot"])
	assert_object(TipSlip.offer(host, _app, tips)).is_null()
	await _launch()
	assert_bool(_app.new_run(SEED + 1, true)).is_true()
	assert_object(TipSlip.offer(_app.switcher.current(), _app, tips)).is_null()


func test_never_in_the_demo_or_the_arrival() -> void:
	_app.new_run(SEED)
	var tips: Array[String] = ["tip.plot", "tip.debuffs", "tip.memory"]
	assert_object(TipSlip.offer(_app.switcher.current(), _app, tips)).is_null()
	var intro: Node = _app.show_screen("set_intro", true)
	assert_object(await _tip(intro)).is_null()
	_app.arrival.start(true)
	await await_idle_frame()
	assert_object(TipSlip.offer(_app.switcher.current(), _app, tips)).is_null()
	assert_array(Profile.read(Saves.profile_service()).seen).is_equal(["tutorial"])
