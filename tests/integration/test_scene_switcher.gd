extends GdUnitTestSuite
## The scene switcher shows one screen at a time with a back stack, and going back or
## changing screens never touches the run, which lives beside it.

const SCREEN: String = "res://tests/fixtures/screens/blank_screen.tscn"


func _switcher() -> SceneSwitcher:
	var host: Node = auto_free(Node.new())
	var switcher: SceneSwitcher = auto_free(SceneSwitcher.new())
	var scene: PackedScene = load(SCREEN)
	var screens: Dictionary[String, PackedScene] = {"a": scene, "b": scene, "c": scene}
	switcher.setup(host, screens)
	return switcher


func test_push_shows_one_screen_and_back_returns() -> void:
	var switcher: SceneSwitcher = _switcher()
	switcher.push("a")
	switcher.push("b")
	assert_str(switcher.current_id()).is_equal("b")
	assert_int(switcher.current().get_parent().get_child_count()).is_equal(1)
	assert_bool(switcher.back()).is_true()
	assert_str(switcher.current_id()).is_equal("a")
	assert_bool(switcher.back()).is_false()


func test_replace_clears_the_way_back() -> void:
	var switcher: SceneSwitcher = _switcher()
	switcher.push("a")
	switcher.push("b")
	switcher.replace("c")
	assert_str(switcher.current_id()).is_equal("c")
	assert_bool(switcher.back()).is_false()


func test_screens_and_back_keep_the_run() -> void:
	var controller: RunController = auto_free(RunController.new())
	controller.start_run(3901, RunScript.bots())
	var before: Dictionary = controller.state_copy().to_dict()
	var switcher: SceneSwitcher = _switcher()
	for screen_id: String in ["a", "b", "c"]:
		switcher.push(screen_id)
	switcher.back()
	switcher.back()
	assert_dict(controller.state_copy().to_dict()).is_equal(before)
