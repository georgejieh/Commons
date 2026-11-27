extends GdUnitTestSuite
## The prompt over the action buttons stands in its box at every text size (ADR 0034, rule
## 10): the box is as tall as the tallest prompt at Standard, and a prompt keeps the chosen
## size unless it would stand taller than the box there, when its type fits down, never
## under Standard.

const SEED: int = 4301

var _app: App


func before_test() -> void:
	Saves.use_run_path(TestFolder.of("test_prompt_fit") + "run.json")
	Saves.run_service().delete()
	_app = AppKit.make(self)
	_app.new_run(SEED)


func after_test() -> void:
	Settings.set_value(TextSize.SETTING, 0)
	Saves.run_service().delete()


func test_every_prompt_stands_in_its_box_at_the_chosen_size_or_fitted_down() -> void:
	var prompts: Array[String] = PromptLines.every(_app.controller, false)
	prompts.append_array(PromptLines.every(_app.controller, true))
	var problems: PackedStringArray = []
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		var table: TableScreen = _app.show_screen("table", true)
		await await_idle_frame()
		var actions: ActionBar = table.actions
		var chosen: int = TextSize.px(ActionBar.PROMPT_SIZE)
		for prompt: String in prompts:
			actions.say(prompt)
			var size: int = actions.prompt_size()
			var where: String = "size %d, %s" % [level, prompt.replace("\n", " / ")]
			if actions.reading.get_minimum_size().y > actions.prompt_room():
				problems.append("%s: stands taller than its box" % where)
			if size < TextSize.least(ActionBar.PROMPT_SIZE) or size > chosen:
				problems.append("%s: type %d" % [where, size])
			if size < chosen and not _overflows_at(actions, chosen):
				problems.append("%s: fitted to %d though %d fits" % [where, size, chosen])
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()


## The box is the tallest prompt at Standard, whatever size is chosen.
func test_the_box_is_the_tallest_prompt_at_standard() -> void:
	var rooms: Array[float] = []
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		var table: TableScreen = _app.show_screen("table", true)
		await await_idle_frame()
		rooms.append(table.actions.prompt_room())
	assert_float(rooms[0]).is_greater(0.0)
	for room: float in rooms:
		assert_float(room).is_equal(rooms[0])


## Whether the prompt shown now would stand taller than its box at font_size.
func _overflows_at(actions: ActionBar, font_size: int) -> bool:
	var fitted: int = actions.prompt_size()
	actions.reading.add_theme_font_size_override("font_size", font_size)
	var over: bool = actions.reading.get_minimum_size().y > actions.prompt_room()
	actions.reading.add_theme_font_size_override("font_size", fitted)
	return over
