extends GdUnitTestSuite
## The norm (P5.2a). The owner could not tell whether beating a Quota raised the next one.
## It does: each full quarter over a Quota's target is a step, up to four, and each step
## raises every later Quota's target by 3% of its base, added, never compounded. The
## Quota's report now says how far the target was beaten and what that did to the norm,
## and the next Quota's introduction says how far the norm raised its target and why.

const SEED: int = 5303
## Every Quota's target after the first, so the raise reads as a plain figure.
const LATER_TARGET: float = 1000.0

static var _save_path: String = TestFolder.of("test_norm_shown") + "run.json"

var _app: DemoApp
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	Settings.set_value("reduced_motion", true)
	Saves.use_run_path(_save_path)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)


func after_test() -> void:
	Settings.set_value(TextSize.SETTING, 0)
	Settings.set_value("reduced_motion", false)
	get_tree().root.size = _was_size
	Saves.run_service().delete()


## A first Quota every run beats four steps over, and plain later ones.
## A target past reach for every Quota when the first is: targets never fall.
func _sets(first: float) -> SetConfig:
	var params: SetParams = SetConfig.DEFAULT_PARAMS.duplicate()
	params.targets = params.targets.duplicate()
	params.targets.fill(maxf(LATER_TARGET, first))
	params.targets[0] = first
	return SetConfig.new(params)


func _play_first_quota(first: float) -> void:
	_app.controller.start_run(SEED, RunScript.bots(), _sets(first))
	var driver: ControllerScript = ControllerScript.new()
	while driver.act(_app.controller):
		pass
	assert_int(_app.controller.awaiting()).is_equal(RunController.AWAIT_SET_OVER)


func test_beating_a_quota_raises_the_next_target_three_percent_a_step() -> void:
	_play_first_quota(0.01)
	var steps: int = _app.controller.figures.over_steps()
	var per_step: int = SetConfig.DEFAULT_PARAMS.norm_percent_per_step
	assert_int(per_step).is_equal(3)
	assert_int(steps).is_equal(SetConfig.DEFAULT_PARAMS.over_max_steps)
	assert_int(_app.controller.figures.norm_added_percent()).is_equal(steps * per_step)
	_app.controller.finish_set()
	_app.controller.leave_store()
	var raised: float = LATER_TARGET * (100 + steps * per_step) / 100.0
	assert_float(_app.controller.figures.target()).is_equal_approx(raised, 0.001)
	# The Quota's start, which the table's bar shows, carries the raised target.
	var started: float = -1.0
	for event: RunEvent in _app.controller.set_events():
		if event.type == RunEvent.Type.SET_STARTED:
			started = event.amount
	assert_float(started).is_equal_approx(raised, 0.001)


func test_the_report_says_how_far_the_quota_was_beaten_and_what_the_norm_did() -> void:
	_play_first_quota(0.01)
	var report: SetSummaryScreen = _app.show_screen("set_summary", true)
	await await_idle_frame()
	var state: RunState = _app.controller.state_copy()
	var target: float = _app.controller.figures.target()
	var over: int = floori((state.set_progress - target) * 100.0 / target)
	var expected: String = (
		tr("summary.norm_raised")
		. format(
			{
				"over": over,
				"added": _app.controller.figures.norm_added_percent(),
				"total": _app.controller.figures.norm_percent(),
			}
		)
	)
	assert_str(report.norm_text()).is_equal(expected)


## Beaten by less than a quarter, the report says the norm stayed where it was.
func test_a_quota_beaten_by_less_than_a_quarter_says_the_norm_stayed() -> void:
	_play_first_quota(0.01)
	var loop: RunLoop = FileWatchKit.loop_of(_app.controller)
	loop.state.norm_steps -= loop.state.over_steps
	loop.state.over_steps = 0
	var target: float = _app.controller.figures.target()
	loop.state.set_progress = target * 1.105
	var report: SetSummaryScreen = _app.show_screen("set_summary", true)
	await await_idle_frame()
	assert_str(report.norm_text()).is_equal(tr("summary.norm_kept").format({"over": 10}))


func test_the_next_quota_says_how_far_the_norm_raised_its_target() -> void:
	_play_first_quota(0.01)
	_app.controller.finish_set()
	_app.controller.leave_store()
	var intro: Control = _app.show_screen("set_intro", true)
	await await_idle_frame()
	var line: String = tr("intro.norm").format(
		{"percent": _app.controller.figures.norm_percent(), "step": 3}
	)
	assert_bool(_has_label(intro, line)).is_true()


func _has_label(root: Node, text: String) -> bool:
	for node: Node in root.find_children("*", "Label", true, false):
		if (node as Label).text == text:
			return true
	return false
