extends GdUnitTestSuite
## A key changed on the Controls page (ADR 0035) moves the action everywhere it is read:
## at the table, in the Campaign tray and into the reading picker, and the old key no
## longer does it. Key events go to the table as the engine hands them on.

const SEED: int = 4242
const SEEDS: int = 12
const SAVE_PATH: String = "user://test_remapped_keys/run.json"
const WAIT_SECONDS: float = 12.0
const SCREEN: Vector2i = Vector2i(1920, 1080)
const WORKERS: Array[String] = ["model_worker", "model_worker"]

var _app: DemoApp
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	get_tree().root.size = SCREEN
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)


func after_test() -> void:
	Settings.bindings.restore_defaults()
	get_tree().root.size = _was_size
	Saves.run_service().delete()


func _loop() -> RunLoop:
	return _app.controller.run_loop()


func _key(table: TableScreen, key: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	table.call("_unhandled_input", event)


## A new run played to the player's first lead, holding these Campaigns.
func _to_first_lead(seed_value: int, held: Array[String]) -> bool:
	_app.new_run(seed_value)
	_loop().state.inventory.consumables.assign(held)
	var driver: ControllerScript = ControllerScript.new()
	for _step: int in 900:
		var awaiting: int = _app.controller.awaiting()
		var view: SeatView = _app.controller.seat_view()
		if awaiting == RunController.AWAIT_PLAY and view.public.history.is_empty():
			return true
		if awaiting == RunController.AWAIT_SET_OVER:
			_app.controller.finish_set()
		elif awaiting == RunController.AWAIT_STORE:
			_loop().state.inventory.consumables.assign(held)
			_app.controller.leave_store()
		elif not driver.act(_app.controller):
			return false
	return false


func _open_table() -> TableScreen:
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	await await_idle_frame()
	return table


func _wait_idle(table: TableScreen) -> void:
	var player: EventPlayer = table.get("_player")
	var waited: float = 0.0
	while not player.is_idle() and waited < WAIT_SECONDS:
		await get_tree().process_frame
		waited += get_process_delta_time()


func test_a_moved_key_acts_at_the_table_and_the_old_one_does_not() -> void:
	assert_bool(_to_first_lead(SEED, [])).is_true()
	var table: TableScreen = await _open_table()
	await _wait_idle(table)
	Settings.bindings.bind("commons_sort", KEY_J)
	Settings.bindings.bind("commons_hint", KEY_K)
	var sort: HandView.Sort = table.sort_mode()
	_key(table, KEY_S)
	assert_int(table.sort_mode()).is_equal(sort)
	_key(table, KEY_J)
	assert_int(table.sort_mode()).is_not_equal(sort)
	var hand_view: HandView = table.get("_hand_view")
	var ticked: Callable = func() -> bool:
		return hand_view.views().any(func(view: CardView) -> bool: return view.shows_hint_tick())
	_key(table, KEY_H)
	assert_bool(ticked.call()).is_false()
	_key(table, KEY_K)
	assert_bool(ticked.call()).is_true()


func test_a_moved_key_reaches_the_campaign_tray() -> void:
	assert_bool(_to_first_lead(SEED, ["grain_loan", "model_harvest"])).is_true()
	var table: TableScreen = await _open_table()
	var campaigns: TableCampaigns = table.get("_campaigns")
	var tray: CampaignTray = campaigns.tray
	Settings.bindings.bind("commons_campaign", KEY_G)
	Settings.bindings.bind("commons_play", KEY_P)
	_key(table, KEY_C)
	assert_int(tray.cursor_slot()).is_equal(-1)
	_key(table, KEY_G)
	assert_int(tray.cursor_slot()).is_equal(0)
	_key(table, KEY_ENTER)
	assert_int(tray.armed_slot()).is_equal(-1)
	_key(table, KEY_P)
	assert_int(tray.armed_slot()).is_equal(0)


## Play on its new key opens the reading picker for cards with more than one reading;
## on its old key it does not, and while the picker is open the new key acts on nothing
## behind it.
func test_a_moved_play_key_opens_the_reading_picker() -> void:
	var found: Array = await _table_with_choice()
	assert_bool(found.is_empty()).override_failure_message("no choice found").is_false()
	var table: TableScreen = found[0]
	var ids: Array[int] = found[1]
	var wild: TableWild = table.get("_wild")
	var picker: ReadingPicker = wild.picker
	Settings.bindings.bind("commons_play", KEY_P)
	_app.hand.clear()
	for card_id: int in ids:
		_app.hand.toggle(card_id)
	var commands: int = _loop().record.commands.size()
	_key(table, KEY_ENTER)
	assert_bool(picker.visible).is_false()
	_key(table, KEY_P)
	assert_bool(picker.visible).is_true()
	_key(table, KEY_P)
	assert_bool(picker.visible).is_true()
	assert_int(_loop().record.commands.size()).is_equal(commands)


## Over a few seeds, a table where Model Worker made a rank wild and the player, leading,
## holds cards with a choice of reading. Returns the table and the cards, or nothing.
func _table_with_choice() -> Array:
	for seed_value: int in range(SEED, SEED + SEEDS):
		if not _to_first_lead(seed_value, WORKERS):
			continue
		var table: TableScreen = await _open_table()
		for _use: int in WORKERS.size():
			if _app.controller.campaign(0) != RunController.OK:
				break
			await _wait_idle(table)
			var ids: Array[int] = _choice_ids()
			if not ids.is_empty():
				return [table, ids]
	return []


## Three of a rank and one other card the player could play more than one way now.
func _choice_ids() -> Array[int]:
	var cards: Array[CardInstance] = _app.controller.player_cards()
	var by_rank: Dictionary[int, Array] = {}
	for card: CardInstance in cards:
		if card.base_rank() <= Ranks.TWO:
			if not by_rank.has(card.base_rank()):
				by_rank[card.base_rank()] = []
			by_rank[card.base_rank()].append(card.id())
	for rank: int in by_rank:
		if by_rank[rank].size() < 3:
			continue
		for other: CardInstance in cards:
			if other.base_rank() == rank or other.base_rank() > Ranks.TWO:
				continue
			var ids: Array[int] = []
			ids.assign(by_rank[rank].slice(0, 3))
			ids.append(other.id())
			if _app.controller.readings_for(ids).size() > 1:
				return ids
	return []
