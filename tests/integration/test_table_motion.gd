extends GdUnitTestSuite
## Table motion (P3B.6): the deal, sweep and count-up run as tweens bound to the nodes
## they move, so none is left once the table is gone; a sweep hands its cards back to
## the pool; and reduced motion turns shake and hit-stop off.

const SEED: int = 4301
const SAVE_PATH: String = "user://test_table_motion/run.json"
## Long enough that any tween left without its node would still be running.
const SLOW: float = 5.0
## Longer than any entrance on the screen shown after the table.
const SETTLE_MS: int = 1200

var _app: DemoApp
var _was_reduced: bool
var _saved_presets: Dictionary[String, float] = {}


func before_test() -> void:
	_was_reduced = bool(Settings.value("reduced_motion"))
	Settings.set_value("reduced_motion", false)
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)
	_app.new_run(SEED)


func after_test() -> void:
	for key: String in _saved_presets:
		TableMotion.PRESETS.set(key, _saved_presets[key])
	_saved_presets.clear()
	Settings.set_value("reduced_motion", _was_reduced)
	Saves.run_service().delete()


func test_no_tween_outlives_the_table() -> void:
	_slow_presets()
	await await_millis(SETTLE_MS)
	var before: int = get_tree().get_processed_tweens().size()
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	_start_every_motion(table)
	assert_int(get_tree().get_processed_tweens().size()).is_greater(before)
	_app.show_screen("settings", true)
	await await_millis(SETTLE_MS)
	assert_int(get_tree().get_processed_tweens().size()).is_less_equal(before)


func test_a_sweep_gives_its_cards_back_to_the_pool() -> void:
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	var pool: CardPool = table.get("_pool")
	var pile: TrickPile = table.get("_pile")
	var free_before: int = pool.free_count()
	pile.show_play(_cards(3), Vector2.ZERO)
	assert_int(pool.free_count()).is_equal(free_before - 3)
	pile.sweep(Vector2.ZERO)
	assert_int(pile.card_count()).is_equal(3)
	await await_millis(int((TableMotion.PRESETS.sweep + 0.3) * 1000.0))
	assert_int(pile.card_count()).is_equal(0)
	assert_int(pool.free_count()).is_equal(free_before)


func test_a_ledger_score_counts_up_to_its_value() -> void:
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	var ledger: Ledger = table.get("_ledger")
	ledger.start_round(1)
	ledger.set_pending("Pair")
	ledger.add_play(1, 96.0, 5.0, 480.0)
	ledger.add_play(2, 20.0, 2.0, 40.0)
	ledger.add_play(0, 30.0, 2.0, 60.0)
	assert_bool(ledger.is_counting()).is_true()
	await await_millis(int((UiMotion.PRESETS.count_time + 0.3) * 1000.0))
	assert_bool(ledger.is_counting()).is_false()
	assert_float(ledger.total_of(1)).is_equal(480.0)
	# The Commons pool is what the two peasants scored between them.
	assert_float(ledger.pool()).is_equal(100.0)
	assert_str(ledger.row_texts()[0]).contains(Strings.score(480.0))
	assert_bool(_shown_texts(ledger).has(Strings.score(480.0))).is_true()


func test_reduced_motion_turns_off_shake_and_hit_stop() -> void:
	Settings.set_value("reduced_motion", true)
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	var motion: TableMotion = table.get("_motion")
	motion.impact()
	assert_float(motion.trauma()).is_equal(0.0)
	assert_bool(motion.is_stopped()).is_false()


func test_turning_reduced_motion_on_stops_a_shake_under_way() -> void:
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	var motion: TableMotion = table.get("_motion")
	motion.impact()
	assert_float(motion.trauma()).is_greater(0.0)
	Settings.set_value("reduced_motion", true)
	assert_bool(motion.reduced).is_true()
	assert_float(motion.trauma()).is_equal(0.0)
	assert_bool(motion.is_stopped()).is_false()


func test_reduced_motion_clears_a_sweep_at_once() -> void:
	Settings.set_value("reduced_motion", true)
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	var pile: TrickPile = table.get("_pile")
	pile.show_play(_cards(2), Vector2.ZERO)
	pile.sweep(Vector2.ZERO)
	assert_int(pile.card_count()).is_equal(0)


## A deal, a play dropped and swept, a ledger count and a bomb's shake, all at once.
func _start_every_motion(table: TableScreen) -> void:
	var hand_view: HandView = table.get("_hand_view")
	hand_view.show_cards()
	hand_view.deal_in()
	var pile: TrickPile = table.get("_pile")
	pile.show_play(_cards(4), Vector2.ZERO)
	pile.sweep(Vector2.ZERO)
	var ledger: Ledger = table.get("_ledger")
	ledger.add_play(1, 60.0, 5.0, 300.0)
	var motion: TableMotion = table.get("_motion")
	motion.impact()


func _slow_presets() -> void:
	for key: String in ["fly_time", "sweep", "count_time", "stamp_time"]:
		_saved_presets[key] = float(TableMotion.PRESETS.get(key))
		TableMotion.PRESETS.set(key, SLOW)


func _cards(count: int) -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for deck_id: int in count:
		cards.append(CardInstance.from_deck_id(deck_id))
	return cards


func _shown_texts(ledger: Ledger) -> PackedStringArray:
	var texts: PackedStringArray = []
	for child: Node in ledger.find_children("*", "Label", true, false):
		texts.append((child as Label).text)
	return texts
