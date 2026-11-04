extends GdUnitTestSuite
## A Cadre bought in the store stays bought through the next Set, through the UI, and
## after leaving to the title and pressing Continue.

const SEED: int = 4242
const SAVE_PATH: String = "user://test_store_ui/run.json"

var _app: DemoApp


func before_test() -> void:
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)
	_app.new_run(SEED)


func after_test() -> void:
	Saves.run_service().delete()


func _to_store(resume_first: bool) -> void:
	var driver: ControllerScript = ControllerScript.new()
	var turns: int = 0
	while _app.controller.awaiting() != RunController.AWAIT_SET_OVER:
		driver.act(_app.controller)
		turns += 1
		if resume_first and turns == 3:
			assert_bool(_app.continue_run()).is_true()
	_app.controller.finish_set()


func _buy_through_the_screen() -> String:
	var store: StoreScreen = _app.show_screen("store", true)
	await await_idle_frame()
	var bought: String = ""
	for slot: int in _app.controller.store_stock().size():
		if _app.controller.can_buy(slot):
			bought = _app.controller.store_stock()[slot]
			for button: Button in store.find_children("*", "Button", true, false):
				if button.theme_type_variation == CommonsTheme.COUPON and not button.disabled:
					button.pressed.emit()
					break
			break
	return bought


func test_a_bought_cadre_lasts_into_the_next_set() -> void:
	_to_store(false)
	var bought: String = await _buy_through_the_screen()
	assert_str(bought).is_not_empty()
	var held: Array[String] = _app.controller.state_copy().inventory.cadres
	assert_array(held).contains([bought])
	_app.controller.leave_store()
	assert_array(_app.controller.state_copy().inventory.cadres).contains([bought])


func test_a_bought_cadre_survives_a_resume_before_the_store() -> void:
	_to_store(true)
	var bought: String = await _buy_through_the_screen()
	if bought.is_empty():
		return
	_app.controller.leave_store()
	assert_array(_app.controller.state_copy().inventory.cadres).contains([bought])
	assert_bool(_app.continue_run()).is_true()
	assert_array(_app.controller.state_copy().inventory.cadres).contains([bought])
