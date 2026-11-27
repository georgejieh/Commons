extends GdUnitTestSuite
## What a deal shows before the bid, on screen (ADR 0043): in the Handicap's Set the cards
## it sets aside lie face up on the pile under a note that names them and the boss, and are
## swept off, unless motion is reduced, and the rules slip names them either way; the
## kitty the Tally Clerk shows lies face up under its note, still on a replay, until the
## seat is chosen.

const SEED: int = 4242
const KITTY: String = "51,52,53"
const HANDICAP: ModifierDef = preload("res://data/modifiers/bosses/the_handicap.tres")
## Every other official, as if each had already run, so the Year's official is the Handicap.
const OFFICIALS: Array[String] = ["struggle_session", "requisition", "great_leap", "the_purge"]
## A Year in which the Handicap sets two cards aside.
const YEAR: int = 4
## The most commands a test gives before the next deal: far more than a round takes.
const MOST_COMMANDS: int = 400
## Seconds the table may take to play a round's end and the next deal.
const DEAL_WAIT: float = 30.0

var _app: App


func before_test() -> void:
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)
	_app.new_run(SEED)


func after_test() -> void:
	Settings.set_value("reduced_motion", false)
	Saves.run_service().delete()


## The table at the Handicap's Set, its first deal made before the table was shown.
func _handicap_table() -> TableScreen:
	var state: RunState = RunState.new(SEED)
	state.year = YEAR
	state.set_type = RunState.SetType.BOSS
	state.officials_used.assign(OFFICIALS)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots())
	loop.start_set()
	assert_str(loop.state.boss_id).is_equal(HANDICAP.id)
	_app.controller.resume(loop, Saves.run_service())
	return await _table()


## Gives the player's commands, each one's events played at once before the next, until a
## command deals again and sets cards aside. That command's events are left to play at the
## table's pace. Fails the test when no deal comes.
func _deal_again(table: TableScreen) -> void:
	var dealt: Array[bool] = [false]
	var watch: Callable = func(event: RunEvent) -> void:
		dealt[0] = dealt[0] or event.type == RunEvent.Type.CARDS_SET_ASIDE
	_app.controller.event_emitted.connect(watch)
	var script: ControllerScript = ControllerScript.new()
	for _command: int in MOST_COMMANDS:
		table.skip_events()
		if _app.controller.awaiting() == RunController.AWAIT_SWAP:
			_app.controller.swap([], [])
		elif not script.act(_app.controller):
			break
		if dealt[0]:
			break
	_app.controller.event_emitted.disconnect(watch)
	assert_bool(dealt[0]).override_failure_message("no deal set cards aside").is_true()


func _aside() -> Array[CardInstance]:
	return _app.controller.run_loop().set_aside_cards()


func _aside_names() -> String:
	var names: PackedStringArray = []
	for card: CardInstance in _aside():
		names.append(CardName.of(card))
	return ", ".join(names)


func test_set_aside_cards_lie_on_the_pile_and_are_swept_off() -> void:
	var table: TableScreen = await _handicap_table()
	var beats: DealMoments = table.deal_beats
	var pile: TrickPile = table.pile
	_deal_again(table)
	assert_int(_aside().size()).is_equal(HandicapEffect.count_at(HANDICAP.parameters, YEAR))
	var said: String = tr("beat.set_aside").format(
		{"name": tr(HANDICAP.name_key), "cards": _aside_names()}
	)
	var noted: Callable = func() -> bool: return beats.note_text() == said
	await TestWait.until(self, noted, "the note over the set-aside cards", DEAL_WAIT)
	var ids: Array[int] = []
	for card: CardInstance in _aside():
		ids.append(card.id())
	assert_array(pile.top_ids()).contains_exactly_in_any_order(ids)
	var swept: Callable = func() -> bool:
		return pile.card_count() == 0 and beats.note_text().is_empty()
	await TestWait.until(self, swept, "the set-aside cards to be swept off")
	await _assert_slip_names_them(table)


func test_under_reduced_motion_the_slip_alone_names_the_set_aside_cards() -> void:
	Settings.set_value("reduced_motion", true)
	var table: TableScreen = await _handicap_table()
	var beats: DealMoments = table.deal_beats
	var pile: TrickPile = table.pile
	var seen: Array[String] = []
	var look: Callable = func(event: RunEvent) -> void:
		if event.type == RunEvent.Type.CARDS_SET_ASIDE:
			seen.append("%s|%d" % [beats.note_text(), pile.card_count()])
	table.player.played.connect(look)
	_deal_again(table)
	var played: Callable = func() -> bool: return not seen.is_empty()
	await TestWait.until(self, played, "the set-aside to play at the table", DEAL_WAIT)
	assert_array(seen).is_equal(["|0"])
	await _assert_slip_names_them(table)


## Once the table has played what it was given, the rules slip names the boss and the
## cards it set aside.
func _assert_slip_names_them(table: TableScreen) -> void:
	await TestWait.until(self, table.player.is_idle, "the table to play out the deal", DEAL_WAIT)
	var slip: String = table.debuffs.lines.get_parsed_text()
	assert_str(slip).contains(tr(HANDICAP.name_key))
	assert_str(slip).contains(tr("table.set_aside").format({"cards": _aside_names()}))


func _table() -> TableScreen:
	_app.show_screen(ScreenId.TABLE, true)
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
