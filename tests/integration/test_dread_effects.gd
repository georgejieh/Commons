extends GdUnitTestSuite
## The Plan's four slow horrors (P5.2c): the eyes on the card backs, the hand's tremble,
## the names leaving the wall roster and speech turning to slogans. Each is nothing on a
## clean profile at any board, grows with the corruption stage under its meter, is gone at
## the lowest horror intensity, and moves nothing the player clicks or reads.

const SEED: int = 4301
const LAST_STAGE: int = BoardState.CORRUPTION_STAGES - 1
## Famine and Denunciation forced for each effect: its own meter high, the other low.
const DRIVERS: Dictionary[String, Vector2i] = {
	DreadEffects.EYES: Vector2i(10, 100),
	DreadEffects.TREMBLE: Vector2i(100, 10),
	DreadEffects.ROSTER: Vector2i(100, 10),
	DreadEffects.SLOGANS: Vector2i(10, 100),
}
const SETTINGS: Array[String] = [
	"horror_intensity", "no_flash", "reduced_motion", "content_note_seen"
]
## Seconds a frame lasts when a test steps the effects by hand.
const FRAME: float = 0.05

var _app: DemoApp
var _saved: Dictionary[String, Variant] = {}


func before_test() -> void:
	for key: String in SETTINGS:
		_saved[key] = Settings.value(key)
	Settings.set_value("horror_intensity", 1.0)
	Settings.set_value("no_flash", false)
	Settings.set_value("reduced_motion", false)
	Settings.set_value("content_note_seen", true)
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)
	_app.new_run(SEED)


func after_test() -> void:
	for key: String in _saved:
		Settings.set_value(key, _saved[key])
	Saves.run_service().delete()


func _table() -> TableScreen:
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	table.skip_events()
	await await_idle_frame()
	# The tests step the effects themselves, frame by frame.
	var dread: DreadLayers = table.get("_dread")
	dread.set_process(false)
	return table


func _force(table: TableScreen, effect: String, stage: int) -> DreadLayers:
	var dread: DreadLayers = table.get("_dread")
	var meters: Vector2i = DRIVERS[effect]
	dread.force(meters.x, meters.y, false, stage)
	return dread


func test_no_effect_shows_on_a_clean_profile_at_any_board() -> void:
	var table: TableScreen = await _table()
	var dread: DreadLayers = table.get("_dread")
	for state: String in BoardState.BOARD_STATES:
		var inputs: Vector3 = BoardState.BOARD_STATES[state]
		dread.force(int(inputs.x), int(inputs.y), inputs.z > 0.0, 0)
		for effect: String in DreadEffects.NAMES:
			var at: String = "%s at %s" % [effect, state]
			assert_float(dread.effect_weight(effect)).override_failure_message(at).is_equal(0.0)
	dread.force(100, 100, true, 0)
	assert_float(BackEyes.shown).is_equal(0.0)


func test_each_effect_grows_with_the_stage_under_its_meter() -> void:
	var table: TableScreen = await _table()
	for effect: String in DreadEffects.NAMES:
		var last: float = 0.0
		for stage: int in range(1, LAST_STAGE + 1):
			var weight: float = _force(table, effect, stage).effect_weight(effect)
			var at: String = "%s at stage %d: %.3f after %.3f" % [effect, stage, weight, last]
			assert_bool(weight >= last).override_failure_message(at).is_true()
			last = weight
		assert_float(last).override_failure_message(effect).is_greater(0.9)
		# Its meter makes the most of it: calm meters at the last stage show less.
		var dread: DreadLayers = table.get("_dread")
		dread.force(10, 10, false, LAST_STAGE)
		assert_float(dread.effect_weight(effect)).override_failure_message(effect).is_less(last)


func test_the_lowest_intensity_shows_none_of_them() -> void:
	var table: TableScreen = await _table()
	Settings.set_value("horror_intensity", 0.0)
	var dread: DreadLayers = table.get("_dread")
	dread.force(100, 100, false, LAST_STAGE)
	for effect: String in DreadEffects.NAMES:
		assert_float(dread.effect_weight(effect)).override_failure_message(effect).is_equal(0.0)
	assert_float(BackEyes.shown).is_equal(0.0)
	var dressing: DreadDressing = table.get("_dressing")
	var roster: WallRoster = dressing.roster()
	assert_int(roster.names_left()).is_equal(roster.name_count())
	var tremble: HandTremble = dread.get("_tremble")
	tremble.step(FRAME, dread.effect_weight(DreadEffects.TREMBLE))
	var hand: HandView = table.get("_hand_view")
	for view: CardView in hand.views():
		assert_vector(view.offset_transform_position).is_equal(Vector2.ZERO)


func test_the_eyes_print_faintly_then_follow_the_pointer() -> void:
	var table: TableScreen = await _table()
	var seats: Dictionary[int, SeatPanel] = table.get("_seats")
	var eyes: BackEyes = _eyes_on(seats[1])
	assert_object(eyes).is_not_null()
	assert_int(eyes.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	var seat_rect: Rect2 = seats[1].get_global_rect()
	var tuning: DreadEffects = DreadLayers.CONFIG.effect_tuning
	_force(table, DreadEffects.EYES, 0)
	await _step_eyes(eyes)
	assert_float(eyes.drawn_ink()).is_equal(0.0)
	# Early, a faint print that looks straight ahead.
	_force(table, DreadEffects.EYES, 3)
	assert_float(BackEyes.shown).is_greater(0.0)
	assert_float(BackEyes.shown).is_less(tuning.eyes_follow_at)
	await _step_eyes(eyes)
	assert_float(eyes.drawn_ink()).is_greater(0.0)
	assert_vector(eyes.look()).is_equal(Vector2.ZERO)
	# Late, darker, and turning toward the pointer, which rests far from the seat.
	var faint: float = eyes.drawn_ink()
	_force(table, DreadEffects.EYES, LAST_STAGE)
	await _step_eyes(eyes)
	assert_float(eyes.drawn_ink()).is_greater(faint)
	assert_float(eyes.look().length()).is_greater(0.5)
	assert_bool(seats[1].get_global_rect().is_equal_approx(seat_rect)).is_true()
	# Under reduced motion the gaze settles back to straight ahead.
	Settings.set_value("reduced_motion", true)
	await _step_eyes(eyes)
	assert_vector(eyes.look()).is_equal(Vector2.ZERO)
	# A card back in flight carries the same eye.
	var back: CardBack = auto_free(CardBack.new())
	var printed: Array[Node] = back.get_children().filter(
		func(node: Node) -> bool: return node is BackEyes
	)
	assert_int(printed.size()).is_equal(1)


func test_the_hand_trembles_without_moving_a_card() -> void:
	var table: TableScreen = await _table()
	var hand: HandView = table.get("_hand_view")
	var dread: DreadLayers = table.get("_dread")
	var tremble: HandTremble = dread.get("_tremble")
	# The fan at rest, its deal over.
	await await_millis(1500)
	var rects: Dictionary[int, Rect2] = {}
	for view: CardView in hand.views():
		rects[view.card_id] = view.get_global_rect()
	assert_int(rects.size()).is_greater(10)
	_force(table, DreadEffects.TREMBLE, 0)
	assert_int(_shaking(tremble, dread, hand)).is_equal(0)
	_force(table, DreadEffects.TREMBLE, 2)
	var early: int = _shaking(tremble, dread, hand)
	_force(table, DreadEffects.TREMBLE, LAST_STAGE)
	var late: int = _shaking(tremble, dread, hand)
	assert_int(early).is_greater(0)
	assert_int(late).is_greater(early)
	for view: CardView in hand.views():
		var at: String = "card %d" % view.card_id
		var drawn: Vector2 = view.offset_transform_position
		var reach: float = DreadLayers.CONFIG.effect_tuning.tremble_px + 0.01
		var near: bool = absf(drawn.x) <= reach and absf(drawn.y) <= reach
		assert_bool(near).override_failure_message(at).is_true()
		var rect: Rect2 = view.get_global_rect()
		var kept: bool = rect.is_equal_approx(rects[view.card_id])
		assert_bool(kept).override_failure_message(at).is_true()
		assert_bool(hand.card_rect(view.card_id).is_equal_approx(rects[view.card_id])).is_true()
	Settings.set_value("reduced_motion", true)
	assert_int(_shaking(tremble, dread, hand)).is_equal(0)
	Settings.set_value("reduced_motion", false)
	_shaking(tremble, dread, hand)
	tremble.still()
	for view: CardView in hand.views():
		assert_bool(view.offset_transform_enabled).is_false()


func test_names_leave_the_roster_with_the_stage_under_famine() -> void:
	var table: TableScreen = await _table()
	var dressing: DreadDressing = table.get("_dressing")
	var roster: WallRoster = dressing.roster()
	var seats: Dictionary[int, SeatPanel] = table.get("_seats")
	var names: PackedStringArray = [_seat_name(seats[1]), _seat_name(seats[2])]
	assert_int(roster.name_count()).is_equal(RunDefaults.VILLAGE.families.size())
	_force(table, DreadEffects.ROSTER, 0)
	assert_int(roster.names_left()).is_equal(roster.name_count())
	_force(table, DreadEffects.ROSTER, 3)
	var early: int = roster.names_left()
	_force(table, DreadEffects.ROSTER, LAST_STAGE)
	var late: int = roster.names_left()
	assert_int(early).is_less(roster.name_count())
	assert_int(late).is_less(early)
	assert_int(late).is_greater(0)
	# The seats' own names are never the roster's.
	assert_str(_seat_name(seats[1])).is_equal(names[0])
	assert_str(_seat_name(seats[2])).is_equal(names[1])


func test_speech_turns_to_slogans_by_degrees_then_unison() -> void:
	var table: TableScreen = await _table()
	var speech: TableSpeech = table.get("_speech")
	var seats: Dictionary[int, SeatPanel] = table.get("_seats")
	speech.hurrying = true
	var said: Array[SpeechLine] = []
	speech.spoke.connect(
		func(_seat: int, _event: String, line: SpeechLine) -> void: said.append(line)
	)
	var lines: int = 24
	for stage: int in [0, 6, LAST_STAGE]:
		_force(table, DreadEffects.SLOGANS, stage)
		said.clear()
		for index: int in lines:
			speech.say(1 + index % 2, "pass")
		var slogans: int = 0
		for line: SpeechLine in said:
			if line.mood == SpeechBook.SLOGAN:
				slogans += 1
		match stage:
			0:
				assert_int(slogans).is_equal(0)
				assert_int(said.size()).is_equal(lines)
			6:
				assert_int(slogans).is_greater(0)
				assert_int(slogans).is_less(lines)
				# No unison yet: one line for each turn to speak.
				assert_int(said.size()).is_equal(lines)
			_:
				# Every line a slogan, each said by both villagers at once.
				assert_int(said.size()).is_equal(lines * 2)
				assert_int(slogans).is_equal(lines * 2)
				assert_str(seats[1].speech()).is_equal(seats[2].speech())


func _eyes_on(seat: SeatPanel) -> BackEyes:
	var back: TextureRect = seat.get("_back")
	for child: Node in back.get_children():
		if child is BackEyes:
			return child as BackEyes
	return null


func _seat_name(seat: SeatPanel) -> String:
	var name: Label = seat.get("_name")
	return name.text


## Turns the eye for two seconds, then lets it draw.
func _step_eyes(eyes: BackEyes) -> void:
	for _frame: int in 40:
		eyes.call("_process", FRAME)
	await await_idle_frame()
	await await_idle_frame()


## How many of the fan's cards are shaking after a few frames.
func _shaking(tremble: HandTremble, dread: DreadLayers, hand: HandView) -> int:
	for _frame: int in 6:
		tremble.step(FRAME, dread.effect_weight(DreadEffects.TREMBLE))
	var moved: int = 0
	for view: CardView in hand.views():
		if view.offset_transform_position != Vector2.ZERO:
			moved += 1
	return moved
