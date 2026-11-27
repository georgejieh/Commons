extends GdUnitTestSuite
## Wild ranks at the table (ADR 0029). A rank made wild is called out and named on the
## rules strip, one rank or two; every wild card in the hand carries its ribbon and no card
## does without one, clear of the index and every other mark in the narrowest fan; the
## reading picker opens only when the chosen cards can be played more than one way, plays
## the reading chosen, cancels with the selection kept and works by keyboard actions,
## clear of the hand and the buttons; a stand-in on the pile names the rank it stands for;
## the hint plays the reading it meant; and the Rules sheet has a section on wild ranks
## only while one is wild, inside the screen.

const SEED: int = 4242
const SEEDS: int = 12
const WAIT_SECONDS: float = 12.0
const SCREEN: Vector2i = Vector2i(1920, 1080)
const WORKERS: Array[String] = ["model_worker", "model_worker"]

var _app: DemoApp
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	get_tree().root.size = SCREEN
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)


func after_test() -> void:
	get_tree().root.size = _was_size
	ArtStages.stage_override = -1
	Saves.run_service().delete()


func _loop() -> RunLoop:
	return _app.controller.run_loop()


## A new run with the player holding these Campaigns, played to the player's first turn as
## landlord, where Model Worker may be used and the player leads.
func _to_first_lead(seed_value: int, held: Array[String]) -> bool:
	_app.new_run(seed_value)
	_loop().state.inventory.consumables.assign(held)
	var driver: ControllerScript = ControllerScript.new()
	for _step: int in 900:
		var awaiting: int = _app.controller.awaiting()
		var view: SeatView = _app.controller.table.seat_view()
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
	var player: EventPlayer = table.player
	await TestWait.until(
		self, func() -> bool: return player.is_idle(), "the table's events to play", WAIT_SECONDS
	)


func _press(action: String) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _wild(table: TableScreen) -> TableWild:
	return table.wild


func _rank_of(card_id: int) -> int:
	for card: CardInstance in _app.controller.table.player_cards():
		if card.id() == card_id:
			return card.base_rank()
	return Ranks.INVALID


## Cards the player could play more than one way now: three of a rank and one other card,
## the first such set found, or none.
func _choice_ids() -> Array[int]:
	var cards: Array[CardInstance] = _app.controller.table.player_cards()
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
			if _app.controller.table.readings_for(ids).size() > 1:
				return ids
	return []


## Over a few seeds, a table where Model Worker made a rank wild and the player, leading,
## holds cards with a choice of reading. Returns the cards, or none.
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


func _select(ids: Array[int]) -> void:
	_app.hand.clear()
	for card_id: int in ids:
		_app.hand.toggle(card_id)


func _last_command() -> Dictionary:
	return _loop().record.commands[-1]


func test_the_call_out_strip_and_ribbons_name_the_wild_ranks() -> void:
	assert_bool(_to_first_lead(SEED, WORKERS)).is_true()
	var table: TableScreen = await _open_table()
	var hand_view: HandView = table.hand_view
	var strip: DebuffStrip = table.debuffs
	var moments: TableMoments = table.moments
	for view: CardView in hand_view.views():
		assert_bool(view.shows_wild()).is_false()
	assert_str(strip.shown_text()).not_contains(tr("wild.strip"))
	assert_int(_app.controller.campaign(0)).is_equal(RunController.OK)
	var first: int = _app.controller.table.wild_ranks()[0]
	await TestWait.until(
		self, func() -> bool: return moments.callout.is_showing(), "the callout", WAIT_SECONDS
	)
	var one: Array[int] = [first]
	assert_str(moments.callout.shown_word()).is_equal(ReadingText.wild_line(one).to_upper())
	await _wait_idle(table)
	# The wild ranks are the strip's first line, above anything the trick may cover.
	assert_str(strip.shown_text()).starts_with(ReadingText.wild_line(one))
	var marked: int = 0
	for view: CardView in hand_view.views():
		var wild: bool = _rank_of(view.card_id) == first
		assert_bool(view.shows_wild()).is_equal(wild)
		marked += 1 if wild else 0
	assert_int(marked).is_equal(_count_of(first))
	# A second rank reads as two, on the strip and under the call-out.
	assert_int(_app.controller.campaign(0)).is_equal(RunController.OK)
	var both: Array[int] = _app.controller.table.wild_ranks()
	assert_int(both.size()).is_equal(2)
	var line: String = ReadingText.wild_line(both)
	var said: Callable = func() -> bool: return moments.callout.shown_sub().contains(line)
	await TestWait.until(self, said, "the callout's line", WAIT_SECONDS)
	assert_str(moments.callout.shown_sub()).contains(ReadingText.wild_line(both))
	await _wait_idle(table)
	assert_str(strip.shown_text()).contains(ReadingText.wild_line(both))
	assert_array(_wild(table).ranks).is_equal(both)
	for view: CardView in hand_view.views():
		assert_bool(view.shows_wild()).is_equal(both.has(_rank_of(view.card_id)))


func _count_of(rank: int) -> int:
	var count: int = 0
	for card: CardInstance in _app.controller.table.player_cards():
		count += 1 if card.base_rank() == rank else 0
	return count


func test_the_ribbon_keeps_clear_of_the_index_and_every_mark_in_the_narrowest_fan() -> void:
	var scene: PackedScene = load("res://ui/cards/card_view.tscn")
	var view: CardView = auto_free(scene.instantiate())
	add_child(view)
	var card: CardInstance = Deck.new().card(Ranks.TEN * Deck.SUITS + 1)
	card.set_owner_stamp(0)
	card.set_enhancement(CardInstance.MODEL)
	for note: String in ["", "as Q"]:
		view.bind(card)
		view.set_rank_note(note)
		view.set_wild(true)
		var ribbon: Rect2 = view.ribbon_rect()
		var parts: Array[Control] = [
			view.get_node("Frame/Suit"),
			view.chop,
			view.badge,
		]
		if not note.is_empty():
			parts.append(view.get_node("Frame/RankNote"))
		for part: Control in parts:
			var box: Rect2 = Rect2(part.position, part.size)
			assert_bool(ribbon.intersects(box)).override_failure_message(part.name).is_false()
		# Under the rank glyph, which ends where the suit pip begins.
		var rank: Label = view.get_node("Frame/Rank")
		var glyph: float = rank.position.y + rank.get_combined_minimum_size().y
		assert_float(ribbon.position.y).is_greater_equal(glyph)
	# The narrowest fan the hand makes, a landlord's twenty cards, leaves the ribbon showing.
	var hand_width: float = 1080.0
	var spacing: float = minf(HandView.MAX_SPACING, hand_width / 20.0)
	assert_float(view.ribbon_rect().end.x).is_less(spacing)
	view.bind(card)
	assert_bool(view.shows_wild()).is_false()


func test_the_picker_opens_only_with_a_choice_plays_by_keys_and_cancels_cleanly() -> void:
	var found: Array = await _table_with_choice()
	assert_bool(found.is_empty()).override_failure_message("no choice found").is_false()
	var table: TableScreen = found[0]
	var ids: Array[int] = found[1]
	var picker: ReadingPicker = _wild(table).picker
	var readings: Array[Pattern] = _app.controller.table.readings_for(ids)
	_select(ids)
	table.actions.play.pressed.emit()
	assert_bool(picker.visible).is_true()
	assert_array(Array(picker.shown())).is_equal(Array(ReadingText.describe_all(readings)))
	assert_int(picker.focused()).is_equal(0)
	assert_int(picker.get_index()).is_equal(table.get_child_count() - 1)
	var slip: Rect2 = picker.slip_rect()
	var hand_view: HandView = table.hand_view
	assert_bool(slip.intersects(hand_view.get_global_rect())).is_false()
	assert_bool(slip.intersects(table.actions.get_global_rect())).is_false()
	assert_bool(Rect2(Vector2.ZERO, Vector2(SCREEN)).encloses(slip)).is_true()
	# Cancel closes it with the selection kept and nothing sent.
	var commands: int = _loop().record.commands.size()
	_press("ui_down")
	assert_int(picker.focused()).is_equal(1)
	_press("ui_cancel")
	assert_bool(picker.visible).is_false()
	assert_int(_loop().record.commands.size()).is_equal(commands)
	var kept: Array[int] = _app.hand.selected_ids()
	kept.sort()
	var wanted: Array[int] = ids.duplicate()
	wanted.sort()
	assert_array(kept).is_equal(wanted)
	# Opened again, down and confirm play the second reading.
	table.actions.play.pressed.emit()
	assert_int(picker.focused()).is_equal(0)
	_press("ui_down")
	_press("ui_accept")
	assert_bool(picker.visible).is_false()
	var last: Dictionary = _last_command()
	assert_str(str(last["type"])).is_equal("play")
	var played: Pattern = ReadingCodec.decode(last[ReadingCodec.KEY])
	assert_bool(played.same_reading(readings[1])).is_true()


func test_one_reading_plays_straight_away() -> void:
	assert_bool(_to_first_lead(SEED, [])).is_true()
	var table: TableScreen = await _open_table()
	var ids: Array[int] = ControllerScript.new().choose_play(_app.controller)
	assert_bool(ids.is_empty()).is_false()
	assert_int(_app.controller.table.readings_for(ids).size()).is_equal(1)
	var commands: int = _loop().record.commands.size()
	_select(ids)
	table.actions.play.pressed.emit()
	assert_bool(_wild(table).picker.visible).is_false()
	assert_int(_loop().record.commands.size()).is_equal(commands + 1)


func test_a_stand_in_on_the_pile_names_the_rank_it_stands_for() -> void:
	var found: Array = await _table_with_choice()
	assert_bool(found.is_empty()).is_false()
	var table: TableScreen = found[0]
	var ids: Array[int] = found[1]
	var readings: Array[Pattern] = _app.controller.table.readings_for(ids)
	# The strongest reading is the bomb, in which wild cards stand in.
	var strongest: Pattern = readings[0]
	var held: Dictionary[int, CardInstance] = {}
	for card: CardInstance in _app.controller.table.player_cards():
		held[card.id()] = card
	_select(ids)
	table.actions.play.pressed.emit()
	_wild(table).picker.choice(0).pressed.emit()
	var pile: TrickPile = table.pile
	await TestWait.until(
		self,
		func() -> bool: return pile.top_ids().size() == ids.size(),
		"the play to land on the pile",
		WAIT_SECONDS
	)
	var cards: Array[CardInstance] = []
	var views: Array[CardView] = pile.top_views()
	for view: CardView in views:
		cards.append(held[view.card_id])
	var stands: PackedByteArray = PlayPlacement.stands_for(cards, strongest)
	var wild: Array[int] = _app.controller.table.wild_ranks()
	var noted: int = 0
	for index: int in views.size():
		var own: int = cards[index].base_rank()
		assert_bool(views[index].shows_wild()).is_equal(wild.has(own))
		if stands[index] != own:
			noted += 1
			var named: String = tr(CardView.RANK_KEYS[stands[index]])
			assert_str(views[index].rank_note()).is_equal(
				tr("card.rank_as").format({"rank": named})
			)
		else:
			assert_str(views[index].rank_note()).is_empty()
	assert_int(noted).is_equal(strongest.stand_ins())


func test_the_hint_plays_the_reading_it_meant() -> void:
	var found: Array = await _table_with_choice()
	assert_bool(found.is_empty()).is_false()
	var table: TableScreen = found[0]
	# The hint keeps the reading of the play it offers, and pressing Play plays that one
	# with no reading asked for.
	var hinted: Array[int] = _app.hand.take_hint()
	assert_array(hinted).is_not_empty()
	var meant: Pattern = _app.hand.hint_reading()
	assert_int(hinted.size()).is_equal(meant.card_count)
	table.actions.play.pressed.emit()
	assert_bool(_wild(table).picker.visible).is_false()
	var played: Array[int] = []
	played.assign(_last_command()["cards"])
	played.sort()
	hinted.sort()
	assert_array(played).is_equal(hinted)


func test_the_rules_sheet_explains_wild_ranks_only_while_one_is_wild() -> void:
	assert_bool(_to_first_lead(SEED, WORKERS)).is_true()
	var table: TableScreen = await _open_table()
	var sheet: CheatSheet = table.cheat_sheet
	sheet.toggle(_app.controller)
	assert_str(sheet.wild_text()).is_empty()
	sheet.toggle(_app.controller)
	assert_int(_app.controller.campaign(0)).is_equal(RunController.OK)
	await _wait_idle(table)
	sheet.toggle(_app.controller)
	await await_idle_frame()
	var text: String = sheet.wild_text()
	assert_str(text).contains(ReadingText.wild_line(_app.controller.table.wild_ranks()))
	for key: String in ["cheat.wild.stand_in", "cheat.wild.order", "cheat.wild.grain"]:
		assert_str(text).contains(tr(key))
	assert_str(text).not_contains(tr("cheat.wild.order.big"))
	sheet.toggle(_app.controller)
	# Under Industrialization it names bigger bombs too, and the sheet still fits.
	_loop().state.reforms.assign(["industrialization"])
	_loop().rebuild_modifiers()
	sheet.toggle(_app.controller)
	await await_idle_frame()
	assert_str(sheet.wild_text()).contains(tr("cheat.wild.order.big"))
	var active: Label = sheet.active_rules
	assert_str(active.text).contains(tr("reform.industrialization.name"))
	var screen: Rect2 = Rect2(Vector2.ZERO, Vector2(SCREEN))
	var inside: bool = screen.encloses(sheet.sheet_rect())
	assert_bool(inside).override_failure_message(str(sheet.sheet_rect())).is_true()
	# However many rules are in play, the sheet is drawn smaller, never cut off.
	active.text = "\n".join(PackedStringArray([active.text, active.text, active.text]))
	await await_idle_frame()
	await await_idle_frame()
	inside = screen.encloses(sheet.sheet_rect())
	assert_bool(inside).override_failure_message(str(sheet.sheet_rect())).is_true()
	sheet.toggle(_app.controller)
	# The next round has no wild rank, and the section goes.
	var round_index: int = _loop().state.round_index
	var driver: ControllerScript = ControllerScript.new()
	for _step: int in 400:
		if _loop().state.round_index > round_index or not driver.act(_app.controller):
			break
	assert_array(_app.controller.table.wild_ranks()).is_empty()
	sheet.toggle(_app.controller)
	assert_str(sheet.wild_text()).is_empty()
