extends GdUnitTestSuite
## The open rules card follows the run within the same frame (P3B.5): at every run event,
## before any frame is drawn, its rank order and active rules match the controller's.

## A seed whose first Set reaches Criticism Meeting in round 3, so the order changes.
const SEED: int = 3
const SAVE_PATH: String = "user://test_cheat_sheet/run.json"
const RANK_DEBUFF: String = "criticism_meeting"

var _app: DemoApp
var _sheet: CheatSheet
var _mismatches: PackedStringArray = []
var _orders_seen: Dictionary[String, bool] = {}
var _saw_debuff_listed: bool = false


func before_test() -> void:
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)
	_app.new_run(SEED)


func after_test() -> void:
	Saves.run_service().delete()


func test_the_open_sheet_matches_the_run_at_every_event() -> void:
	assert_array(_app.controller.ladder()).contains([RANK_DEBUFF])
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	_sheet = table.get("_cheat_sheet")
	_sheet.toggle(_app.controller)
	# Connected after the sheet, so this runs once the sheet has redrawn for the event.
	_app.controller.event_emitted.connect(_check)
	var driver: ControllerScript = ControllerScript.new()
	for _turn: int in 600:
		if _app.switcher.current_id() != "table":
			break
		table.skip_events()
		if _app.switcher.current_id() != "table":
			break
		_press(table, driver)
		await await_idle_frame()
	_app.controller.event_emitted.disconnect(_check)
	assert_array(_mismatches).is_empty()
	assert_int(_orders_seen.size()).is_greater(1)
	assert_bool(_saw_debuff_listed).is_true()


func _check(_event: RunEvent) -> void:
	if not _sheet.visible or _app.controller.seat_view() == null:
		return
	var expected: String = _expected_order()
	if _sheet.rank_order_text() != expected:
		_mismatches.append("%s != %s" % [_sheet.rank_order_text(), expected])
	_orders_seen[expected] = true
	var active: String = _sheet.active_text()
	for modifier_id: String in _app.controller.active_modifier_ids():
		if not active.contains(tr("modifier.%s.name" % modifier_id)):
			_mismatches.append("missing %s" % modifier_id)
		if modifier_id == RANK_DEBUFF:
			_saw_debuff_listed = true


## The rank order from the controller's own map, built apart from the sheet.
func _expected_order() -> String:
	var rank_map: PackedByteArray = _app.controller.player_table().rank_map
	var ranks: Array[int] = []
	for rank: int in Ranks.COUNT:
		ranks.append(rank)
	ranks.sort_custom(func(a: int, b: int) -> bool: return rank_map[a] < rank_map[b])
	var glyphs: PackedStringArray = []
	for rank: int in ranks:
		glyphs.append(tr(CardView.RANK_KEYS[rank]))
	return tr("cheat.order").format({"order": " < ".join(glyphs)})


func _press(table: TableScreen, driver: ControllerScript) -> void:
	match _app.controller.awaiting():
		RunController.AWAIT_BID:
			table.actions().decline.pressed.emit()
		RunController.AWAIT_NEED:
			table.need_panel().declared.emit(ControllerScript.NEED)
		RunController.AWAIT_PLAY:
			var ids: Array[int] = driver.choose_play(_app.controller)
			if ids.is_empty():
				table.actions().pass_turn.pressed.emit()
				return
			for card_id: int in ids:
				_app.hand.toggle(card_id)
			table.actions().play.pressed.emit()
