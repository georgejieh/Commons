extends GdUnitTestSuite
## Dread layers (P3B.12): weights follow the Plan's seven board states and ease toward
## them; horror intensity 0 gives the clean board; horror never changes a value the
## player reads; no-flash stops every flicker; and the content note leads a first launch.

const SEED: int = 4301
const SAVE_PATH: String = "user://test_dread_layers/run.json"
const CONFIG: HorrorConfig = preload("res://data/horror/horror_config.tres")
## Layer indices in horror_config.tres.
const FAMINE: int = 0
const DENUNCIATION: int = 1
const STRUGGLE: int = 2
const LANDLORD: int = 3
const SETTINGS: Array[String] = ["horror_intensity", "no_flash", "content_note_seen"]

var _app: DemoApp
var _saved: Dictionary[String, Variant] = {}


func before_test() -> void:
	for key: String in SETTINGS:
		_saved[key] = Settings.value(key)
	Settings.set_value("horror_intensity", 1.0)
	Settings.set_value("no_flash", false)
	Settings.set_value("content_note_seen", true)
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)
	_app.new_run(SEED)


func after_test() -> void:
	for key: String in _saved:
		Settings.set_value(key, _saved[key])
	Saves.run_service().delete()


func test_each_board_state_lights_its_layers() -> void:
	var expected: Dictionary[String, Array] = {
		"both_low": [],
		"famine_mid": [FAMINE],
		"famine_high": [FAMINE],
		"denunciation_mid": [DENUNCIATION],
		"denunciation_high": [DENUNCIATION],
		"both_high": [FAMINE, DENUNCIATION, STRUGGLE],
		"landlord": [LANDLORD],
	}
	for state: String in BoardState.BOARD_STATES:
		var inputs: Vector3 = BoardState.BOARD_STATES[state]
		var board: BoardState = BoardState.new(CONFIG)
		board.set_inputs(int(inputs.x), int(inputs.y), inputs.z > 0.0, 0)
		for layer: int in CONFIG.layers.size():
			var lit: bool = expected[state].has(layer)
			var weight: float = board.targets[layer]
			(
				assert_bool(weight > 0.2 if lit else weight < 0.1)
				. override_failure_message("%s layer %d at %.2f" % [state, layer, weight])
				. is_true()
			)
	var high: BoardState = BoardState.new(CONFIG)
	high.set_inputs(90, 10, false, 0)
	var mid: BoardState = BoardState.new(CONFIG)
	mid.set_inputs(55, 10, false, 0)
	assert_float(high.targets[FAMINE]).is_greater(mid.targets[FAMINE])


func test_weights_ease_over_several_seconds() -> void:
	var board: BoardState = BoardState.new(CONFIG)
	board.set_inputs(100, 0, false, 0)
	board.step(1.0)
	assert_float(board.weights[FAMINE]).is_less(board.targets[FAMINE])
	assert_float(board.weights[FAMINE]).is_greater(0.0)
	for _second: int in int(CONFIG.ease_seconds) + 1:
		board.step(1.0)
	assert_float(board.weights[FAMINE]).is_equal_approx(board.targets[FAMINE], 0.001)


func test_corruption_adds_a_layer_under_the_meters() -> void:
	var board: BoardState = BoardState.new(CONFIG)
	board.set_inputs(0, 0, false, BoardState.CORRUPTION_STAGES - 1)
	assert_float(board.targets[CONFIG.layers.size() - 1]).is_equal_approx(1.0, 0.001)
	assert_float(board.targets[FAMINE]).is_equal(0.0)


func test_intensity_zero_is_the_clean_board() -> void:
	var dread: DreadLayers = await _table_dread()
	dread.force(90, 90, true)
	Settings.set_value("horror_intensity", 0.0)
	dread.apply()
	for layer: HorrorLayer in CONFIG.layers:
		for key: String in layer.shader_params:
			if not is_nan(dread.param_value(key)):
				assert_float(dread.param_value(key)).is_equal(dread.param_clean(key))
		for piece: String in layer.dressing:
			assert_float(dread.piece_weight(piece)).is_equal(0.0)


func test_full_horror_changes_the_board() -> void:
	var dread: DreadLayers = await _table_dread()
	dread.force(90, 90, false)
	assert_float(dread.param_value("post:dread")).is_greater(dread.param_clean("post:dread"))
	assert_float(dread.piece_weight("empty_chairs")).is_greater(0.5)
	assert_float(dread.piece_weight("redaction")).is_greater(0.5)


func test_horror_never_changes_what_the_player_reads() -> void:
	var table: TableScreen = await _open_table()
	var dread: DreadLayers = table.get("_dread")
	Settings.set_value("horror_intensity", 0.0)
	dread.force(0, 0, false)
	await await_idle_frame()
	var clean: PackedStringArray = _readings(table, dread)
	Settings.set_value("horror_intensity", 1.0)
	dread.force(100, 100, true, BoardState.CORRUPTION_STAGES - 1)
	for _frame: int in 3:
		await await_idle_frame()
	assert_array(Array(_readings(table, dread))).is_equal(Array(clean))
	assert_int(clean.size()).is_greater(20)


func test_no_flash_stops_every_flicker() -> void:
	var dread: DreadLayers = await _table_dread()
	dread.set_process(false)
	dread.force(100, 100, false)
	var fired: Array[String] = []
	dread.flickered.connect(func(kind: String) -> void: fired.append(kind))
	for _second: int in 600:
		dread.tick_flickers(1.0)
	assert_array(fired).is_not_empty()
	fired.clear()
	Settings.set_value("no_flash", true)
	for _second: int in 600:
		dread.tick_flickers(1.0)
	assert_array(fired).is_empty()


func test_the_content_note_leads_a_first_launch() -> void:
	Settings.set_value("content_note_seen", false)
	assert_str(_app.first_screen()).is_equal("content_note")
	var note: ContentNoteScreen = _app.show_screen("content_note", true)
	await await_idle_frame()
	var text: String = note.text().to_lower()
	for theme: String in ["famine", "persecution", "surveillance", "horror intensity"]:
		assert_str(text).contains(theme)
	Settings.set_value("content_note_seen", true)
	assert_str(_app.first_screen()).is_equal("title")


func _open_table() -> TableScreen:
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	table.skip_events()
	await await_idle_frame()
	return table


func _table_dread() -> DreadLayers:
	var table: TableScreen = await _open_table()
	return table.get("_dread")


## Every label text and card on the table outside the dread dressing, in tree order.
func _readings(node: Node, dread: DreadLayers) -> PackedStringArray:
	var found: PackedStringArray = []
	var dressing: Node = dread.get("_dressing")
	if node == dressing:
		return found
	var label: Label = node as Label
	if label != null and label.is_visible_in_tree():
		found.append(label.text)
	var card: CardView = node as CardView
	if card != null and card.is_visible_in_tree():
		found.append("card %d" % card.card_id)
	for child: Node in node.get_children():
		found.append_array(_readings(child, dread))
	return found
