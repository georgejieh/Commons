extends GdUnitTestSuite
## The Quota report's seals stand whole (P5.2a): the owner saw the met seal at the bar's
## right end cut off by the Famine figure under it. The bar now stands in a band as tall as
## its widest seal, so the met, overfulfilled and short seals stand clear of the Coupons
## and Famine figures at every text size and both screen sizes.

const SEED: int = 5303
const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 800)]

static var _save_path: String = TestFolder.of("test_summary_seals") + "run.json"

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


## Every Quota at one target: met many times over at the smallest, missed at the largest.
func _play_first_quota(target: float) -> void:
	var params: SetParams = SetConfig.DEFAULT_PARAMS.duplicate()
	params.targets = params.targets.duplicate()
	params.targets.fill(target)
	_app.controller.start_run(SEED, RunScript.bots(), SetConfig.new(params))
	var driver: ControllerScript = ControllerScript.new()
	while driver.act(_app.controller):
		pass
	assert_int(_app.controller.awaiting()).is_equal(RunController.AWAIT_SET_OVER)


## The met seal, the overfulfilled seal and a short Quota's seal stand clear of the
## Coupons and Famine figures, at every text size and both screen sizes.
func test_the_reports_seals_stand_clear_of_the_figures() -> void:
	for first: float in [0.01, 1e12]:
		_play_first_quota(first)
		for level: int in TextSize.count():
			for screen_size: Vector2i in SIZES:
				Settings.set_value(TextSize.SETTING, level)
				get_tree().root.size = screen_size
				var report: SetSummaryScreen = _app.show_screen("set_summary", true)
				await await_idle_frame()
				await await_idle_frame()
				var where: String = "target %s, size %d at %s" % [first, level, screen_size]
				_check_seals(report, where)
				if first > 1.0:
					var short: String = tr("summary.short").to_upper()
					assert_str(report.bar().seal_word()).override_failure_message(where).is_equal(
						short
					)


func _check_seals(report: SetSummaryScreen, where: String) -> void:
	var seals: Array[InkSeal] = [report.bar().get("_seal"), report.over_seal()]
	var shown: int = 0
	var after: Array[Control] = report.get("_after")
	var row: Control = after[0]
	for seal: InkSeal in seals:
		if not seal.visible:
			continue
		shown += 1
		var rect: Rect2 = seal.get_global_rect()
		for tile: Control in row.get_children():
			var at: String = "%s: seal %s on tile %s" % [where, rect, tile.get_global_rect()]
			(
				assert_bool(rect.intersects(tile.get_global_rect()))
				. override_failure_message(at)
				. is_false()
			)
	assert_int(shown).override_failure_message(where).is_greater(0)
