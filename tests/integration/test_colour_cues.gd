extends GdUnitTestSuite
## Nothing the player needs is told by hue alone (ADR 0035): a seat low on cards says so
## in words, a hinted card carries a pencilled tick in every state it can be in, and the
## tutorial's slip refusing a click under reduced motion shows a cross with its border.

const SEED: int = 4301
const SCREENS_AT: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 800)]
const CARD: PackedScene = preload("res://ui/cards/card_view.tscn")
## The narrowest strip of a card the fan leaves showing that the tick must sit in.
const STRIP: float = 40.0

var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size


func after_test() -> void:
	get_tree().root.size = _was_size
	Settings.set_value(TextSize.SETTING, 0)
	Settings.set_value("reduced_motion", false)
	ArtStages.stage_override = -1
	Saves.run_service().delete()


func test_the_seat_count_says_few_cards_in_words() -> void:
	assert_str(SeatPanel.count_text(3)).is_equal("3 cards")
	assert_str(SeatPanel.count_text(2)).is_equal("Only 2 cards")
	assert_str(SeatPanel.count_text(1)).is_equal("Last card")
	assert_str(SeatPanel.count_text(0)).is_equal("0 cards")
	assert_str(SeatPanel.count_text(17)).is_equal("17 cards")
	var panel: SeatPanel = auto_free(SeatPanel.new())
	add_child(panel)
	var count: Label = panel.get("_count")
	for cards: int in [3, 2, 1, 0]:
		panel.set_count(cards)
		assert_str(count.text).is_equal(SeatPanel.count_text(cards))
		var red: bool = count.get_theme_color("font_color") == ScreenKit.SEAL
		assert_bool(red).override_failure_message(str(cards)).is_equal(cards <= 2)


## The longer words fit on every seat at every text size on both screens.
func test_the_few_cards_words_fit_every_seat() -> void:
	AppKit.fresh_saves(self)
	var app: DemoApp = AppKit.make(self)
	app.new_run(SEED)
	var problems: PackedStringArray = []
	for level: int in TextSize.count():
		for screen: Vector2i in SCREENS_AT:
			Settings.set_value(TextSize.SETTING, level)
			get_tree().root.size = screen
			var table: TableScreen = app.show_screen("table", true)
			await await_idle_frame()
			table.skip_events()
			var seats: Dictionary[int, SeatPanel] = table.get("_seats")
			for cards: int in [2, 1]:
				for seat: int in seats:
					seats[seat].set_count(cards)
				await await_idle_frame()
				await await_idle_frame()
				var where: String = "%d cards at size %d on %s" % [cards, level, screen]
				ClipCheck.check(table, where, problems)
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()


func _card() -> CardView:
	var view: CardView = auto_free(CARD.instantiate())
	add_child(view)
	return view


func test_a_hinted_card_shows_its_tick_in_every_state() -> void:
	var view: CardView = _card()
	# selected, hinted, cursor, armed
	var states: Array[Array] = [
		[false, true, false, false],
		[true, true, false, false],
		[true, true, false, true],
		[false, true, true, false],
		[true, true, true, true],
	]
	for state: Array in states:
		view.set_marked(state[0], state[1], state[2], state[3])
		assert_bool(view.shows_hint_tick()).override_failure_message(str(state)).is_true()
	for state: Array in [[false, false, false, false], [true, false, true, true]]:
		view.set_marked(state[0], state[1], state[2], state[3])
		assert_bool(view.shows_hint_tick()).override_failure_message(str(state)).is_false()


## The tick sits above the card's left edge, in the strip the fan leaves showing, and
## takes no part in the card's size or its clicks.
func test_the_tick_leaves_the_card_layout_and_hit_box_alone() -> void:
	var view: CardView = _card()
	var size: Vector2 = view.size
	var minimum: Vector2 = view.get_combined_minimum_size()
	view.set_marked(false, true)
	await await_idle_frame()
	assert_vector(view.size).is_equal(size)
	assert_vector(view.get_combined_minimum_size()).is_equal(minimum)
	var tick: Rect2 = view.hint_tick_rect()
	assert_float(tick.end.y).is_less_equal(0.0)
	assert_float(tick.position.x).is_greater_equal(0.0)
	assert_float(tick.end.x).is_less_equal(STRIP)
	var mark: HintTick = view.get("_tick")
	assert_int(mark.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


## Rough at stage 0 and rougher at the last stage: the wear it draws at grows.
func test_the_tick_is_drawn_rough_and_rougher_with_the_stage() -> void:
	var view: CardView = _card()
	var wears: Array[float] = []
	for stage: int in [0, 9]:
		ArtStages.stage_override = stage
		wears.append(BowlGrime.wear())
		view.set_marked(false, false)
		view.set_marked(false, true)
		await await_idle_frame()
		assert_bool(view.shows_hint_tick()).is_true()
	assert_float(wears[0]).is_greater(0.0)
	assert_float(wears[1]).is_greater(wears[0])


func _slip() -> TutorialSlip:
	var slip: TutorialSlip = auto_free(TutorialSlip.new())
	add_child(slip)
	slip.say("Pick the lowest card.")
	return slip


func test_a_refusal_under_reduced_motion_shows_a_cross_for_its_moment() -> void:
	Settings.set_value("reduced_motion", true)
	var slip: TutorialSlip = _slip()
	await await_idle_frame()
	assert_bool(slip.shows_cross()).is_false()
	slip.refuse()
	assert_bool(slip.shows_cross()).is_true()
	var inside: Rect2 = Rect2(Vector2.ZERO, slip.size)
	assert_bool(inside.encloses(slip.cross_rect())).is_true()
	await get_tree().create_timer(TutorialSlip.ALARM_SECONDS + 0.3).timeout
	assert_bool(slip.shows_cross()).is_false()


func test_a_refusal_with_motion_pulses_and_shows_no_cross() -> void:
	Settings.set_value("reduced_motion", false)
	var slip: TutorialSlip = _slip()
	await await_idle_frame()
	slip.refuse()
	assert_bool(slip.shows_cross()).is_false()
