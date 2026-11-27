extends GdUnitTestSuite
## The debuffs of ADR 0023 on screen: every debuff's name and full rules on the Set intro
## ladder and in the table's debuff strip, dark type at 16 px or more inside the screen
## at 1920x1080 and 1280x800, the Slogan naming its hand type; and the table's beats for
## Levy, Redistribution, Confiscation, Glass Walls, Plot Seized and Night Shift, each
## leaving only its end state under reduced motion.

const SEED: int = 4242
const READABLE: int = 16

var _app: DemoApp
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)
	_app.new_run(SEED)
	# A Quota no one meets, so a Set plays on into its debuffs' rounds.
	_app.controller.start_run(SEED, RunScript.bots(), DebuffScript.hard_sets())


func after_test() -> void:
	Settings.set_value(TextSize.SETTING, 0)
	get_tree().root.size = _was_size
	Settings.set_value("reduced_motion", false)
	Saves.run_service().delete()


func _loop() -> RunLoop:
	return _app.controller.run_loop()


## Puts one debuff in the ladder's second round, a Slogan naming Pairs.
func _ladder(debuff_id: String) -> void:
	var state: RunState = _loop().state
	state.debuff_ladder.assign(["", debuff_id, "", ""])
	state.slogan_type = Pattern.Type.PAIR


func _inside(control: Control, where: String) -> void:
	var screen: Rect2 = Rect2(Vector2.ZERO, Vector2(1920, 1080)).grow(ClipCheck.SLACK)
	var rect: Rect2 = control.get_global_rect()
	(
		assert_bool(screen.encloses(rect))
		. override_failure_message("%s: %s off screen" % [where, rect])
		. is_true()
	)


func test_every_debuff_reads_in_full_on_the_set_intro() -> void:
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		for screen_size: Vector2i in ClipCheck.SIZES:
			get_tree().root.size = screen_size
			for debuff: ModifierDef in DebuffScript.POOL.debuffs:
				_ladder(debuff.id)
				var intro: Control = _app.show_screen("set_intro", true)
				await await_idle_frame()
				await await_idle_frame()
				var where: String = "%s %s" % [debuff.id, screen_size]
				var name: String = _app.controller.texts.modifier_name(debuff.id)
				var rule: String = _app.controller.texts.modifier_text(debuff.id)
				var named: bool = false
				for node: Node in intro.find_children("*", "Label", true, false):
					var label: Label = node
					if label.text == name:
						named = true
						assert_int(label.get_theme_font_size("font_size")).is_greater_equal(
							READABLE
						)
						_inside(label, where)
				assert_bool(named).override_failure_message(where).is_true()
				var ruled: bool = false
				for node: Node in intro.find_children("*", "KeywordText", true, false):
					var text: KeywordText = node
					if text.get_parsed_text() == rule:
						ruled = true
						assert_int(text.get_theme_font_size("normal_font_size")).is_greater_equal(
							READABLE
						)
						var ink: Color = text.get_theme_color("default_color")
						assert_float(ink.get_luminance()).override_failure_message(where).is_less(
							0.3
						)
						_inside(text, where)
				assert_bool(ruled).override_failure_message(where).is_true()
				_clips(intro, where)
	assert_str(_app.controller.texts.modifier_name("slogan_of_the_week")).is_equal(
		"Slogan of the Week: Pairs"
	)


## Each debuff alone on the rules slip, no intel on the seat: in full at Standard on both
## screens, and at every size in full or by name, never cut (ADR 0034, rule 7).
func test_every_debuff_reads_in_full_in_the_table_strip() -> void:
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		for screen_size: Vector2i in ClipCheck.SIZES:
			get_tree().root.size = screen_size
			for debuff: ModifierDef in DebuffScript.POOL.debuffs:
				_ladder(debuff.id)
				_loop().state.round_index = 1
				var table: TableScreen = _app.show_screen("table", true)
				await await_idle_frame()
				var strip: DebuffStrip = table.debuffs
				strip.show_debuffs(_app.controller)
				await await_idle_frame()
				var where: String = "%s %s size %d" % [debuff.id, screen_size, level]
				var shown: String = strip.shown_text()
				assert_str(shown).override_failure_message(where).contains(
					_app.controller.texts.modifier_name(debuff.id)
				)
				if level == 0:
					assert_bool(strip.is_named()).override_failure_message(where).is_false()
				if not strip.is_named():
					assert_str(shown).override_failure_message(where).contains(
						_app.controller.texts.modifier_text(debuff.id)
					)
				assert_int(strip.form()).override_failure_message(where).is_less_equal(
					DebuffStrip.Form.FITTED
				)
				assert_bool(strip.fits()).override_failure_message(where).is_true()
				assert_int(DebuffStrip.FONT_SIZE).is_greater_equal(READABLE)
				_inside(strip, where)
				_clips(table, where)
				_loop().state.round_index = 0


## Plays the player's seat through the table until check returns true, at most turns times.
func _play_until(check: Callable, turns: int = 600) -> bool:
	var driver: ControllerScript = ControllerScript.new()
	_app.show_screen("table", true)
	await await_idle_frame()
	for _turn: int in turns:
		if _app.switcher.current_id() != "table":
			return false
		var table: TableScreen = _app.switcher.current()
		table.skip_events()
		await await_idle_frame()
		# A new round builds the table afresh.
		if _app.switcher.current() != table:
			continue
		if bool(check.call(table)):
			return true
		if not driver.act(_app.controller):
			return false
	return false


func test_levy_and_redistribution_slide_cards_left_or_leave_the_end_state() -> void:
	for reduced: bool in [false, true]:
		Settings.set_value("reduced_motion", reduced)
		_app.show_screen("table", true)
		await await_idle_frame()
		var table: TableScreen = _app.switcher.current()
		var beats: DebuffMoments = table.debuff_beats
		var mine: CardInstance = _app.controller.table.player_cards()[0]
		# A Levy in force: the slip names it, the card and where it goes.
		_ladder("levy")
		_loop().state.round_index = 1
		var given: RunEvent = RunEvent.new(RunEvent.Type.CARDS_PASSED, 0, 2, 0.0, str(mine.id()))
		beats.on_event(given, false)
		assert_bool(beats.is_playing()).is_equal(not reduced)
		var said: String = tr("beat.levy.given").format(
			{"card": CardName.of(mine), "name": _app.seat_name(2)}
		)
		assert_str(beats.note_text()).is_equal("" if reduced else said)
		_check_note(beats, reduced)
		# Redistribution: between two villagers the cards fly face down.
		_ladder("redistribution")
		beats.on_event(RunEvent.new(RunEvent.Type.CARDS_PASSED, 2, 1, 0.0, "40,41"), false)
		var backs: int = 0
		for node: Node in beats.find_children("*", "CardBack", true, false):
			backs += 1 if (node as CanvasItem).visible else 0
		assert_int(backs).is_equal(0 if reduced else 2)
		said = tr("beat.redistribution").format({"count": 2})
		assert_str(beats.note_text()).is_equal("" if reduced else said)
		_check_note(beats, reduced)
		_loop().state.round_index = 0


## The slip by moving cards: dark type at 16 px or more, whole on screen.
func _check_note(beats: DebuffMoments, reduced: bool) -> void:
	assert_bool(beats.note.visible).is_equal(not reduced)
	if reduced:
		return
	var label: Label = beats.note.get_child(0)
	assert_int(label.get_theme_font_size("font_size")).is_greater_equal(READABLE)
	assert_float(label.get_theme_color("font_color").get_luminance()).is_less(0.3)
	_inside(beats.note, "note")


func test_a_confiscated_cadre_is_struck_on_the_board_for_its_round() -> void:
	_loop().state.inventory.cadres.assign(["ration_coupon"])
	_ladder("confiscation")
	var struck: Array[bool] = []
	var reached: bool = await _play_until(
		func(table: TableScreen) -> bool:
			if _loop().state.round_index != 1:
				return false
			var board: NoticeBoard = table.board
			struck.append(board.is_struck(0))
			return true
	)
	assert_bool(reached).is_true()
	assert_array(struck).is_equal([true])


func test_glass_walls_lay_glass_over_the_hand_while_in_force() -> void:
	_ladder("glass_walls")
	var shown: Dictionary[int, String] = {}
	var reached: bool = await _play_until(
		func(table: TableScreen) -> bool:
			var moments: DebuffMoments = table.debuff_beats
			if _app.controller.awaiting() == RunController.AWAIT_PLAY:
				shown[_loop().state.round_index] = moments.glass.shown_text()
			return _loop().state.round_index == 1 and shown.has(1)
	)
	assert_bool(reached).is_true()
	assert_str(shown[0]).is_empty()
	assert_str(shown[1]).is_equal(tr("table.glass_walls"))
	# The slip is tall enough that its printed border clears its line.
	var current: TableScreen = _app.switcher.current()
	var beats: DebuffMoments = current.debuff_beats
	var glass: GlassPane = beats.glass
	var room: Rect2 = glass.slip().get_global_rect().grow(-GlassPane.SLIP_PADDING + 2.0)
	assert_bool(room.encloses(glass.words().get_global_rect())).is_true()
	assert_int(glass.words().get_theme_font_size("font_size")).is_greater_equal(READABLE)


## The line over the hand names the player's role once the round has started.
func test_the_role_line_names_the_players_role_in_the_round() -> void:
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	var driver: ControllerScript = ControllerScript.new()
	assert_bool(driver.play_to(self, _app.controller, RunController.AWAIT_PLAY)).is_true()
	table.skip_events()
	await await_idle_frame()
	var landlord: bool = _app.controller.run.landlord_seat() == Seats.PLAYER
	var role: String = "table.you.landlord" if landlord else "table.you.peasant"
	assert_str(table.you.text).is_equal(tr(role))


func test_a_seized_plot_card_is_torn_unless_motion_is_reduced() -> void:
	for reduced: bool in [false, true]:
		Settings.set_value("reduced_motion", reduced)
		_app.show_screen("table", true)
		await await_idle_frame()
		var table: TableScreen = _app.switcher.current()
		var beats: DebuffMoments = table.debuff_beats
		var seized: RunEvent = RunEvent.new(
			RunEvent.Type.PLOT_SEIZED, 0, CardInstance.FIRST_PLOT_ID, 0.0, "11,1"
		)
		for screen_size: Vector2i in ClipCheck.SIZES:
			get_tree().root.size = screen_size
			await await_idle_frame()
			beats.on_event(seized, false)
			assert_bool(beats.torn.visible).is_equal(not reduced)
			if reduced:
				continue
			# The torn card is held clear of the cut-in's words.
			var moments: TableMoments = table.moments
			var words: Rect2 = moments.callout.text_rect()
			for half: Control in beats.torn.halves():
				(
					assert_bool(half.get_global_rect().intersects(words))
					. override_failure_message("%s: %s over %s" % [screen_size, half, words])
					. is_false()
				)
				_inside(half, "torn card")
		beats.on_event(seized, true)


func test_night_shift_refuses_the_pass_and_says_why() -> void:
	_ladder("night_shift")
	var said: Array[String] = []
	var reached: bool = await _play_until(
		func(table: TableScreen) -> bool:
			if _app.controller.table.pass_refusal().is_empty():
				return false
			var turn: int = _loop().round_state().public_view().history.size()
			table.actions.pass_turn.pressed.emit()
			said.append(table.actions.reading.text)
			assert_int(_loop().round_state().public_view().history.size()).is_equal(turn)
			return true
	)
	assert_bool(reached).is_true()
	assert_array(said).is_equal([tr("table.must_play")])


## Nothing under root clips, as ClipCheck says (ADR 0034).
func _clips(root: Node, where: String) -> void:
	var problems: PackedStringArray = []
	ClipCheck.check(root, "%s at text size %d" % [where, TextSize.level()], problems)
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()
