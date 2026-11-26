extends GdUnitTestSuite
## The table polish left open from the owner's first playtest (P5.2c), each held by a
## rectangle at both screen sizes and every text size: an ink frame on the sheet of the
## villager whose turn it is, following the events; the brigade notice on worn paper with
## its words inside the printed border; each rule's name closed before its text on the
## rules slip; and the reading picker beside the cards it asks about, never on them or on
## a button.

const SEED: int = 4301
const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 800)]
## A tremble of the slip's edge against its subject's, in pixels.
const SLACK: float = 0.5

var _app: DemoApp
var _was_size: Vector2i
var _was_reduced: bool


func before_test() -> void:
	_was_size = get_tree().root.size
	_was_reduced = bool(Settings.value("reduced_motion"))
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)
	_app.new_run(SEED)


func after_test() -> void:
	Settings.set_value(TextSize.SETTING, 0)
	Settings.set_value("reduced_motion", _was_reduced)
	get_tree().root.size = _was_size
	Saves.run_service().delete()


func _table(level: int, screen: Vector2i) -> TableScreen:
	Settings.set_value(TextSize.SETTING, level)
	get_tree().root.size = screen
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	table.skip_events()
	await await_idle_frame()
	await await_idle_frame()
	return table


func _round(type: RoundEvent.Type, seat: int) -> RunEvent:
	return RunEvent.wrap(RoundEvent.new(type, seat))


func test_the_turn_mark_stands_over_the_seat_whose_turn_it_is() -> void:
	for level: int in TextSize.count():
		for screen: Vector2i in SIZES:
			var table: TableScreen = await _table(level, screen)
			var turn: TurnMark = table.get("_turn")
			var seats: Dictionary[int, SeatPanel] = table.get("_seats")
			var where: String = "size %d on %s" % [level, screen]
			assert_int(turn.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
			# Your play hands the turn to the right seat, its pass to the left one, and
			# the left seat's pass back to you, where no seat is marked.
			turn.on_event(_round(RoundEvent.Type.PLAYED, 0))
			_assert_over(turn, seats[1], where)
			turn.on_event(_round(RoundEvent.Type.PASSED, 1))
			_assert_over(turn, seats[2], where)
			turn.on_event(_round(RoundEvent.Type.PASSED, 2))
			assert_bool(turn.visible).override_failure_message(where).is_false()
			turn.on_event(RunEvent.new(RunEvent.Type.BID, 0))
			assert_int(turn.seat).is_equal(1)
			turn.on_event(_round(RoundEvent.Type.ROUND_STARTED, 2))
			assert_int(turn.seat).is_equal(2)
			turn.on_event(_round(RoundEvent.Type.TRICK_WON, 1))
			assert_int(turn.seat).is_equal(1)
			turn.on_event(_round(RoundEvent.Type.ROUND_ENDED, 1))
			assert_bool(turn.visible).is_false()


func _assert_over(turn: TurnMark, seat: SeatPanel, where: String) -> void:
	assert_bool(turn.visible).override_failure_message(where).is_true()
	var frame: Rect2 = turn.get_global_rect()
	var sheet: Rect2 = seat.get_global_rect()
	var at: String = "%s: frame %s on seat %s" % [where, frame, sheet]
	assert_bool(frame.is_equal_approx(sheet)).override_failure_message(at).is_true()


func test_the_brigade_notice_is_worn_paper_with_its_words_inside_the_border() -> void:
	for level: int in TextSize.count():
		for screen: Vector2i in SIZES:
			var table: TableScreen = await _table(level, screen)
			var dressing: DreadDressing = table.get("_dressing")
			var notice: PanelContainer = dressing.get("_notice")
			var where: String = "size %d on %s" % [level, screen]
			var paper: StyleBox = notice.get_theme_stylebox("panel")
			assert_bool(paper is StyleBoxTexture).override_failure_message(where).is_true()
			var inside: Rect2 = dressing.notice_rect().grow(-DreadDressing.NOTICE_PADDING + SLACK)
			var words: Rect2 = dressing.notice_words().get_global_rect()
			var at: String = "%s: %s in %s" % [where, words, inside]
			assert_bool(inside.encloses(words)).override_failure_message(at).is_true()


func test_each_rule_name_is_closed_before_its_text() -> void:
	var debuff: String = DebuffScript.POOL.debuffs[0].id
	var loop: RunLoop = _app.controller.run_loop()
	loop.state.debuff_ladder.assign(["", debuff, "", ""])
	loop.state.round_index = 1
	var name: String = _app.controller.texts.modifier_name(debuff)
	var wild: String = ReadingText.wild_line([Ranks.SEVEN] as Array[int])
	for level: int in TextSize.count():
		for screen: Vector2i in SIZES:
			var table: TableScreen = await _table(level, screen)
			var strip: DebuffStrip = table.get("_debuffs")
			strip.wild_ranks = [Ranks.SEVEN]
			strip.show_debuffs(_app.controller)
			await await_idle_frame()
			var shown: String = strip.shown_text()
			var where: String = "size %d on %s: %s" % [level, screen, shown]
			assert_str(shown).override_failure_message(where).contains(
				wild + DebuffStrip.NAME_END + " "
			)
			if not strip.is_named():
				assert_str(shown).override_failure_message(where).contains(
					name + DebuffStrip.NAME_END + " "
				)


func test_the_reading_picker_stands_beside_the_chosen_cards() -> void:
	Settings.set_value("reduced_motion", true)
	for level: int in TextSize.count():
		for screen: Vector2i in SIZES:
			var table: TableScreen = await _table(level, screen)
			var hand: HandView = table.get("_hand_view")
			for view: CardView in hand.views().slice(4, 7):
				_app.hand.set_selected(view.card_id, true)
			await await_idle_frame()
			var chosen: Rect2 = hand.selection_rect()
			assert_bool(chosen.has_area()).is_true()
			var wild: TableWild = table.get("_wild")
			for readings: Array[Pattern] in [_many(), _many().slice(0, 2)]:
				wild.picker.open(readings, chosen)
				await await_idle_frame()
				var slip: Rect2 = wild.picker.slip_rect()
				var where: String = "size %d on %s: %s by %s" % [level, screen, slip, chosen]
				_assert_beside(slip, chosen, table, where)
				wild.picker.close()
			_app.hand.clear()


func _assert_beside(slip: Rect2, chosen: Rect2, table: TableScreen, where: String) -> void:
	assert_bool(slip.intersects(chosen)).override_failure_message(where).is_false()
	var gap: float = SlipPlacer.distance(slip, chosen)
	assert_bool(gap <= SlipPlacer.REACH + SLACK).override_failure_message(where).is_true()
	var column: Rect2 = table.actions().get_global_rect()
	assert_bool(slip.intersects(column)).override_failure_message(where).is_false()
	var screen: Rect2 = Rect2(0, ReadingPicker.TOP, 1920, 1080 - ReadingPicker.TOP).grow(SLACK)
	assert_bool(screen.encloses(slip)).override_failure_message(where).is_true()


## Sevens wild, and the lead 3 4 7 7 7 7: more than a dozen readings.
func _many() -> Array[Pattern]:
	var sevens: RuleSet = WildReference.rules([Ranks.SEVEN] as Array[int], false)
	return Readings.of(RankText.counts("347777"), sevens, Ranks.identity_map())
