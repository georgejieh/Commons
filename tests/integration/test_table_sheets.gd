extends GdUnitTestSuite
## Faults a reader of the table's frames would see, each held by a rectangle
## and not by an eye: the buttons under the prompt stay where they are when the prompt
## takes a second line; a play's sum and its score share one line of the ledger at a
## size that can be read; the claim sheet leaves no half line showing under it; the
## Glass Walls pane covers a full hand and its slip never lies on the line over the hand;
## a board of empty Cadre slots is not shown; and the arrival's Quota is a figure.

const SEED: int = 3
const TUTORIAL: TutorialScript = preload("res://data/run/tutorial/arrival.tres")
const LEAST_TYPE: int = 16

var _app: App


func before_test() -> void:
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)
	_app.new_run(SEED)


func after_test() -> void:
	Settings.set_value(TextSize.SETTING, 0)
	Saves.run_service().delete()


func _table() -> TableScreen:
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	await await_idle_frame()
	return table


func test_the_buttons_stay_put_when_the_prompt_takes_a_second_line() -> void:
	var table: TableScreen = await _table()
	var actions: ActionBar = table.actions
	actions.show_bidding(false)
	actions.say("Pass.")
	await await_idle_frame()
	await await_idle_frame()
	var play_at: float = actions.play.global_position.y
	var hint_at: float = actions.hint.global_position.y
	var prompt_at: float = actions.reading.global_position.y
	actions.say("You may use a Campaign before the first play, or play on.")
	await await_idle_frame()
	await await_idle_frame()
	assert_int(actions.reading.get_line_count()).is_greater(1)
	assert_float(actions.play.global_position.y).is_equal(play_at)
	assert_float(actions.hint.global_position.y).is_equal(hint_at)
	# The longer prompt grew upward, into the table.
	assert_float(actions.reading.global_position.y).is_less(prompt_at)


func test_a_plays_sum_and_score_share_one_readable_line() -> void:
	var table: TableScreen = await _table()
	var ledger: Ledger = table.ledger
	ledger.start_round(1)
	ledger.set_pending(tr("pattern.trio_pair"))
	ledger.add_play(1, 45.0, 10.0, 1.5, 675.0)
	await await_idle_frame()
	await await_idle_frame()
	var plays: KeywordText = ledger.plays
	# Who played what, then the whole sum with its score: two lines, never three.
	assert_int(plays.get_line_count()).is_equal(2)
	assert_str(plays.get_parsed_text().get_slice("\n", 1)).ends_with(Strings.score(675.0))
	assert_int(TextSize.px(Ledger.SUM_SIZE)).is_greater_equal(LEAST_TYPE)
	assert_int(plays.get_content_width()).is_less_equal(int(plays.size.x) + 1)


func test_no_half_line_shows_under_the_claim_sheet() -> void:
	var table: TableScreen = await _table()
	var line: Label = table.you
	assert_bool(line.visible).is_true()
	var driver: ControllerScript = ControllerScript.new()
	assert_bool(driver.play_to(self, _app.controller, RunController.AWAIT_NEED)).is_true()
	table.skip_events()
	await await_idle_frame()
	await await_idle_frame()
	var need: NeedPanel = table.need_panel
	assert_bool(need.visible).is_true()
	assert_bool(line.visible).is_false()
	var beats: DebuffMoments = table.debuff_beats
	assert_bool(beats.glass.slip().visible).is_false()
	# The sheet stands between the seats, clear of both.
	var sheet: Rect2 = need.get_global_rect()
	var seats: Dictionary[int, SeatPanel] = table.seats
	for seat: int in seats:
		assert_bool(sheet.intersects(seats[seat].get_global_rect())).is_false()
	assert_bool(driver.act(_app.controller)).is_true()
	table.skip_events()
	await await_idle_frame()
	assert_bool(need.visible).is_false()
	assert_bool(line.visible).is_true()


func test_the_glass_covers_a_full_hand_and_its_slip_keeps_off_the_line() -> void:
	var table: TableScreen = await _table()
	var beats: DebuffMoments = table.debuff_beats
	var hand_view: HandView = table.hand_view
	var glass: GlassPane = beats.glass
	glass.set_shown(true, false)
	beats.clear_slip(table.you, false)
	await await_idle_frame()
	var pane: Rect2 = glass.get_global_rect()
	# Every card of the hand lies under the pane, its leaning ends too.
	var shown: int = 0
	for view: CardView in hand_view.views():
		if view.visible:
			shown += 1
			var card: Rect2 = view.get_global_transform() * Rect2(Vector2.ZERO, view.size)
			assert_float(card.position.x).is_greater_equal(pane.position.x)
			assert_float(card.end.x).is_less_equal(pane.end.x)
	assert_int(shown).is_greater_equal(Dealer.HAND_SIZE)
	var line: Label = table.you
	var face: Font = line.get_theme_font("font")
	var type: int = line.get_theme_font_size("font_size")
	var words: float = face.get_string_size(line.text, HORIZONTAL_ALIGNMENT_LEFT, -1, type).x
	var slip: Control = glass.slip()
	if slip.visible:
		assert_float(slip.global_position.x).is_greater_equal(line.global_position.x + words)
	# A line that reaches the slip's place puts the slip away, never under it.
	line.text = "W".repeat(60)
	beats.clear_slip(line, false)
	assert_bool(slip.visible).is_false()
	glass.set_shown(false, false)


func test_a_board_of_empty_slots_is_not_shown() -> void:
	var table: TableScreen = await _table()
	var board: NoticeBoard = table.board
	table.skip_events()
	await await_idle_frame()
	assert_bool(_app.controller.state_copy().inventory.cadres.is_empty()).is_true()
	assert_bool(board.visible).is_false()
	var loop: RunLoop = _app.controller.run_loop()
	loop.state.inventory.cadres.append("canteen")
	table.skip_events()
	await await_idle_frame()
	assert_bool(board.visible).is_true()


func test_the_arrivals_quota_is_a_figure_a_player_can_read() -> void:
	for target: float in TUTORIAL.sets.targets:
		assert_float(target).is_between(1000.0, 99999.0)


func test_at_the_largest_text_the_claim_sheet_and_the_line_keep_off_the_hand() -> void:
	Settings.set_value(TextSize.SETTING, 2)
	await await_idle_frame()
	var table: TableScreen = await _table()
	var need: NeedPanel = table.need_panel
	need.visible = true
	need.ask(9999, "Zhuge", 0.5)
	for _frame: int in 4:
		await await_idle_frame()
	var hand_top: float = TableScreen.HAND_AT.position.y
	var sheet: Rect2 = need.get_global_rect()
	assert_float(sheet.end.y).is_less_equal(hand_top)
	assert_float(sheet.position.y).is_greater_equal(72.0)
	need.visible = false
	# The line over the hand ends where it does at Standard, above a lifted card's top.
	var line: Label = table.you
	var face: Font = line.get_theme_font("font")
	var tall: float = face.get_height(line.get_theme_font_size("font_size"))
	assert_float(line.global_position.y + tall).is_less_equal(hand_top - HandView.LIFT)
