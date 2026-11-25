extends GdUnitTestSuite
## What a deal shows before the bid, on screen (ADR 0043): cards the Handicap sets aside
## lie face up on the pile under a note that names them and the boss, unless motion is
## reduced, and the rules slip names the boss and the cards either way.

const SEED: int = 4242
const SAVE_PATH: String = "user://test_deal_moments/run.json"
const ASIDE: int = 5

var _app: DemoApp


func before_test() -> void:
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)
	_app.new_run(SEED)


func after_test() -> void:
	Settings.set_value("reduced_motion", false)
	Saves.run_service().delete()


func _loop() -> RunLoop:
	return _app.controller.get("_loop")


func _table() -> TableScreen:
	_app.show_screen("table", true)
	await await_idle_frame()
	return _app.switcher.current()


func test_set_aside_cards_lie_on_the_pile_and_the_slip_names_them() -> void:
	for reduced: bool in [false, true]:
		Settings.set_value("reduced_motion", reduced)
		var table: TableScreen = await _table()
		var beats: DealMoments = table.get("_deal_beats")
		var pile: TrickPile = table.get("_pile")
		var strip: DebuffStrip = table.get("_debuffs")
		_loop().state.boss_id = "the_handicap"
		var card: CardInstance = _app.controller.deck_card(ASIDE)
		var deal: DealResult = _loop().get("_deal")
		deal.set_aside.append(card)
		pile.clear()
		beats.on_event(RunEvent.new(RunEvent.Type.CARDS_SET_ASIDE, 0, 0, 0.0, str(ASIDE)), false)
		var name: String = _app.controller.card_name(card)
		var said: String = tr("beat.set_aside").format(
			{"name": tr("modifier.the_handicap.name"), "cards": name}
		)
		assert_str(beats.note_text()).is_equal("" if reduced else said)
		assert_int(pile.card_count()).is_equal(0 if reduced else 1)
		strip.show_debuffs(_app.controller)
		var lines: KeywordText = strip.get("_lines")
		var slip: String = lines.get_parsed_text()
		assert_str(slip).contains(tr("table.boss").to_upper())
		assert_str(slip).contains(tr("modifier.the_handicap.name"))
		assert_str(slip).contains(tr("table.set_aside").format({"cards": name}))
		deal.set_aside.clear()
		_loop().state.boss_id = RunState.NO_BOSS
		strip.show_debuffs(_app.controller)
		assert_str(lines.get_parsed_text()).not_contains(tr("table.boss").to_upper())
