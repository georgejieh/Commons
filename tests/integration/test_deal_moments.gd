extends GdUnitTestSuite
## What a deal shows before the bid, on screen (ADR 0043): the kitty the Tally Clerk shows
## lies face up under its note, still on a replay, until the seat is chosen.

const SEED: int = 4242
const KITTY: String = "51,52,53"

var _app: DemoApp


func before_test() -> void:
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)
	_app.new_run(SEED)


func after_test() -> void:
	Settings.set_value("reduced_motion", false)
	Saves.run_service().delete()


func _loop() -> RunLoop:
	return _app.controller.run_loop()


func _table() -> TableScreen:
	_app.show_screen("table", true)
	await await_idle_frame()
	return _app.switcher.current()


func test_the_kitty_seen_lies_face_up_until_the_seat_is_chosen() -> void:
	for reduced: bool in [false, true]:
		Settings.set_value("reduced_motion", reduced)
		var table: TableScreen = await _table()
		var beats: DealMoments = table.deal_beats
		var pile: TrickPile = table.pile
		pile.clear()
		beats.on_event(RunEvent.new(RunEvent.Type.KITTY_SEEN, 0, 0, 0.0, KITTY), false)
		assert_bool(beats.kitty_shown()).is_true()
		assert_int(pile.card_count()).is_equal(3)
		assert_str(beats.note_text()).is_equal(tr("table.kitty_seen"))
		beats.on_event(RunEvent.new(RunEvent.Type.LANDLORD_CHOSEN, 1, 1), false)
		assert_bool(beats.kitty_shown()).is_false()
		assert_int(pile.card_count()).is_zero()
		assert_str(beats.note_text()).is_empty()
		# Rejoined mid-bid, the replay lays the kitty there still.
		beats.on_event(RunEvent.new(RunEvent.Type.KITTY_SEEN, 0, 0, 0.0, KITTY), true)
		assert_bool(beats.kitty_shown()).is_true()
		assert_int(pile.card_count()).is_equal(3)
		beats.on_event(RunEvent.new(RunEvent.Type.DEALT), false)
		assert_bool(beats.kitty_shown()).is_false()
