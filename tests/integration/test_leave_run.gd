extends GdUnitTestSuite
## Abandoning a run lets it go for good (P5.2a): the controller holds no run afterwards,
## so a villager's search still in flight has nowhere to hand its play in and the cleared
## save stays cleared. The cloud walk caught the save written back after Abandon.

const SEED: int = 11

var _app: DemoApp


func before_test() -> void:
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)
	_app.new_run(SEED)


func after_test() -> void:
	Saves.run_service().delete()


func test_leaving_a_run_lets_it_go_and_the_save_stays_cleared() -> void:
	_app.controller.call("_save")
	assert_bool(FileAccess.file_exists(Saves.run_service().path())).is_true()
	assert_bool(_app.controller.has_run()).is_true()
	_app.leave_run()
	assert_bool(_app.controller.has_run()).is_false()
	assert_int(_app.controller.searches_running()).is_equal(0)
	for _frame: int in 30:
		await await_idle_frame()
	assert_bool(FileAccess.file_exists(Saves.run_service().path())).is_false()
	assert_str(_app.switcher.current_id()).is_equal("title")


func test_a_new_run_starts_clean_after_one_was_left() -> void:
	_app.leave_run()
	_app.new_run(SEED + 1)
	assert_bool(_app.controller.has_run()).is_true()
	_app.controller.call("_save")
	assert_bool(FileAccess.file_exists(Saves.run_service().path())).is_true()
