extends GdUnitTestSuite
## The score tally never lies on the cards laid on the trick, the hand or a seat at 1920x1080
## and 1280x800 and at every text size, through all of its motion: every frame of a big play's
## sequence is measured, its chits' swell and its shake included, not only where it rests. The
## trick holds a 20-card plane, a long pair run and plays buried under them. Fitted to its
## room, its type is never smaller than at Standard.

const SEED: int = 3
## The Quota target the play is measured against: small, so the play lands at its hardest.
const SMALL_TARGET: float = 50.0
const MOST_FRAMES: int = 600

static var _save_path: String = TestFolder.of("test_score_room") + "run.json"

var _app: App
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	Saves.use_run_path(_save_path)
	Saves.run_service().delete()


func after_test() -> void:
	Settings.set_value(TextSize.SETTING, 0)
	Settings.set_value("reduced_motion", false)
	get_tree().root.size = _was_size
	Saves.run_service().delete()


func _table(level: int, screen_size: Vector2i) -> TableScreen:
	Settings.set_value(TextSize.SETTING, level)
	get_tree().root.size = screen_size
	_app = AppKit.make(self)
	_app.new_run(SEED)
	var table: TableScreen = _app.show_screen(App.TABLE, true)
	await await_idle_frame()
	await await_idle_frame()
	return table


## Cards by deck ID from first, count of them.
func _run_of(first: int, count: int) -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for index: int in count:
		cards.append(Deck.new().card(first + index))
	return cards


## Lays plays on the trick as a long trick leaves them, the last a full 20 cards.
func _lay(pile: TrickPile, motion: TableMotion, last_first: int) -> void:
	motion.set_still(true)
	pile.clear()
	var from: Vector2 = pile.global_position + pile.size / 2.0
	pile.show_play(_run_of(0, 2), from)
	pile.show_play(_run_of(8, 5), from)
	pile.show_play(_run_of(20, 12), from)
	pile.show_play(_run_of(last_first, 20), from)
	motion.set_still(false)


## A play changed by several Cadres, scored through the engine, carrying its steps.
func _big_play() -> RunEvent:
	var stack: ModifierStack = ModifierStack.new()
	for id: String in ["red_banner", "iron_and_coal", "poor_peasants_association", "canteen"]:
		stack.add(ResourceLoader.load("res://data/modifiers/%s.tres" % id), 0)
	var cards: Array[CardInstance] = RoundScript.stacked_deal(["333444"], "").hands[0].cards()
	var rules: RuleSet = RuleSet.default_rules()
	var pattern: Pattern = RoundScript.classify(cards, rules, Ranks.identity_map()).pattern
	var score: ScoreBreakdown = Scorer.score_play(
		cards, pattern, 3, 0, false, stack, Scorer.DEFAULT_PARAMS, 0, null, true
	)
	var event: RunEvent = RunEvent.new(RunEvent.Type.PLAY_SCORED, 0, 0, score.total)
	event.grain = score.grain
	event.rate = score.rate
	event.zeal = score.zeal
	event.steps = score.trail
	return event


func test_the_tally_keeps_off_the_cards_the_hand_and_the_seats_through_its_motion() -> void:
	for level: int in TextSize.count():
		for screen_size: Vector2i in ClipCheck.SIZES:
			var where: String = "text size %d at %s" % [level, screen_size]
			var table: TableScreen = await _table(level, screen_size)
			await _check_table(table, where)
			_app.queue_free()
			await await_idle_frame()


func _check_table(table: TableScreen, where: String) -> void:
	var moments: TableMoments = table.moments
	var pile: TrickPile = table.pile
	var motion: TableMotion = table.motion
	var hand: HandView = table.hand_view
	var seats: Dictionary[int, SeatPanel] = table.seats
	var hand_box: Rect2 = hand.get_global_rect()
	var lifted: float = HandView.LIFT + HandView.ARMED_LIFT
	hand_box = Rect2(hand_box.position - Vector2(0, lifted), hand_box.size + Vector2(0, lifted))
	var others: Dictionary[String, Rect2] = {"hand": hand_box}
	for seat: int in seats:
		others["seat %d" % seat] = seats[seat].get_global_rect()
	var room: Rect2 = moments.sequence.room()
	for piece: String in others:
		(
			assert_bool(room.intersects(others[piece]))
			. override_failure_message(where + " room on " + piece)
			. is_false()
		)
	for last_first: int in [0, 13, 27, 34]:
		_lay(pile, motion, last_first)
		await await_idle_frame()
		# Every laid card stays above the lowest the pile says it reaches.
		var floor_y: float = pile.global_position.y + pile.reach_below()
		for card: Rect2 in pile.drawn_rects():
			assert_float(card.end.y).override_failure_message(where).is_less_equal(floor_y + 0.5)
		var cards: Array[Rect2] = pile.drawn_rects()
		moments.on_event(RunEvent.new(RunEvent.Type.SET_STARTED, Seats.NONE, 0, SMALL_TARGET))
		moments.on_event(_big_play())
		var rest: Array[Rect2] = moments.tally.drawn_rects()
		# The line over the hand shares the tally's band, so it steps aside for it.
		var line: Label = table.you
		assert_float(line.modulate.a).override_failure_message(where + " line").is_equal(0.0)
		# Fitted to its room, its type is never drawn smaller than at Standard.
		var drawn: float = moments.tally.scale.x * TextSize.factor()
		assert_float(drawn).override_failure_message(where + " type").is_greater_equal(0.999)
		var moved: bool = false
		var frames: int = 0
		while (moments.sequence.is_running() or moments.tally.visible) and frames < MOST_FRAMES:
			for chit: Rect2 in moments.tally.drawn_rects():
				var at: String = "%s frame %d chit %s" % [where, frames, chit]
				for card: Rect2 in cards:
					(
						assert_bool(chit.intersects(card))
						. override_failure_message(at + " on a card")
						. is_false()
					)
				for piece: String in others:
					var over: bool = chit.intersects(others[piece])
					assert_bool(over).override_failure_message(at + " on " + piece).is_false()
			moved = moved or moments.tally.drawn_rects() != rest
			frames += 1
			await await_idle_frame()
		if not moments.tally.visible:
			assert_float(line.modulate.a).override_failure_message(where + " back").is_equal(1.0)
		# The motion was measured, not only the rest.
		assert_bool(moved).override_failure_message(where + " never moved").is_true()
