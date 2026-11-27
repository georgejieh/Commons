extends GdUnitTestSuite
## A scored play acted out: the cards tick,
## Rate and Zeal land, then each Cadre, mark, level or debuff that changed the score fires
## one at a time in the engine's order, with a tag of what it added and a sound a step up
## (or down, for a cut); then the total rolls and is stamped. The table waits for it, a
## click hurries it, sitting out plays villagers' at the hurried pace, the pace setting
## scales it, long chains speed up within a cap, and reduced motion keeps every tag,
## figure and sound with nothing moving.

const HOLDER: int = 0

## The event queue the last moments made were set up with.
var _events: EventPlayer


func after_test() -> void:
	Settings.set_value("reduced_motion", SettingsStore.DEFAULTS.get("reduced_motion"))


func _def(id: String) -> ModifierDef:
	return ResourceLoader.load("res://data/modifiers/%s.tres" % id)


func _cards(text: String) -> Array[CardInstance]:
	return RoundScript.stacked_deal([text], "").hands[0].cards()


## A real play scored through the engine, with its steps, as PLAY_SCORED carries it.
func _scored(text: String, ids: Array[String], seat: int = HOLDER) -> RunEvent:
	var stack: ModifierStack = ModifierStack.new()
	for id: String in ids:
		stack.add(_def(id), HOLDER)
	var cards: Array[CardInstance] = _cards(text)
	var rules: RuleSet = RuleSet.default_rules()
	var pattern: Pattern = RoundScript.classify(cards, rules, Ranks.identity_map()).pattern
	var score: ScoreBreakdown = Scorer.score_play(
		cards, pattern, 2, seat, false, stack, Scorer.DEFAULT_PARAMS, 0, null, true
	)
	var event: RunEvent = RunEvent.new(RunEvent.Type.PLAY_SCORED, seat, 0, score.total)
	event.grain = score.grain
	event.rate = score.rate
	event.zeal = score.zeal
	event.steps = score.trail
	return event


func _moments() -> TableMoments:
	var moments: TableMoments = auto_free(TableMoments.new())
	var ledger: Ledger = auto_free(Ledger.new())
	var pile: TrickPile = auto_free(TrickPile.new())
	var motion: TableMotion = auto_free(TableMotion.new())
	var player: EventPlayer = auto_free(EventPlayer.new())
	_events = player
	for node: Node in [moments, ledger, pile, motion, player]:
		add_child(node)
	moments.size = Vector2(1920, 1080)
	pile.position = Vector2(470, 380)
	pile.size = Vector2(640, 300)
	var names: Dictionary[int, String] = {0: "You", 1: "Wang", 2: "Zhao"}
	var faces: Dictionary[int, Texture2D] = {}
	moments.setup(ledger, pile, motion, player, {}, names, faces)
	player.played.connect(moments.on_event)
	return moments


func _wait_done(sequence: ScoreSequence, most_ms: int = 6000) -> int:
	var start: int = Time.get_ticks_msec()
	while sequence.is_running() and Time.get_ticks_msec() - start < most_ms:
		await await_idle_frame()
	return Time.get_ticks_msec() - start


func test_each_change_fires_in_order_with_its_tag_and_sound() -> void:
	var moments: TableMoments = _moments()
	var event: RunEvent = _scored("555", ["red_banner", "canteen", "ration_cut"])
	var kinds: Array[int] = []
	var tags: Array[String] = []
	moments.sequence.beat_began.connect(
		func(kind: int, _at: int) -> void:
			kinds.append(kind)
			for label: Label in moments.fx.shown_tags():
				if not tags.has(label.text):
					tags.append(label.text)
	)
	moments.on_event(event)
	await _wait_done(moments.sequence)
	var tick: int = ScoreBeats.Kind.TICK
	var step: int = ScoreBeats.Kind.STEP
	var expected: Array[int] = [ScoreBeats.Kind.ENTER, tick, tick, tick, ScoreBeats.Kind.RATE]
	expected.append_array([ScoreBeats.Kind.ZEAL, step])
	assert_array(kinds.slice(0, 7)).is_equal(expected)
	assert_int(kinds[-2]).is_equal(ScoreBeats.Kind.ROLL)
	assert_int(kinds[-1]).is_equal(ScoreBeats.Kind.STAMP)
	# One tag per change, in the engine's order, each saying what it did.
	var changes: Array[String] = []
	for each: ScoreStep in event.steps:
		if not _is_base(each):
			changes.append(ScoreSequence.tag_text(each))
	assert_array(tags).is_equal(changes)
	var landed: Array[String] = [AudioEvents.SCORE_LAND, AudioEvents.SCORE_LAND_HEAVY]
	assert_bool(landed.has(Audio.last_played)).is_true()
	assert_str(moments.tally.shown()).ends_with(Strings.score(event.amount))


func test_a_tag_says_what_a_step_added() -> void:
	var add: ScoreStep = ScoreStep.new(
		ScoreStep.Figure.GRAIN, ScoreStep.Source.MODIFIER, ScoreStep.Op.ADD, 30.0, 20.0, 50.0
	)
	assert_str(ScoreSequence.tag_text(add)).is_equal("+30 " + tr("keyword.grain.name"))
	var times: ScoreStep = ScoreStep.new(
		ScoreStep.Figure.ZEAL, ScoreStep.Source.MODIFIER, ScoreStep.Op.MUL, 1.5, 1.0, 1.5
	)
	assert_str(ScoreSequence.tag_text(times)).is_equal("×1.5 " + tr("keyword.zeal.name"))
	var cut: ScoreStep = ScoreStep.new(
		ScoreStep.Figure.ZEAL, ScoreStep.Source.MODIFIER, ScoreStep.Op.ADD, -0.5, 1.5, 1.0
	)
	assert_str(ScoreSequence.tag_text(cut)).is_equal("−0.5 " + tr("keyword.zeal.name"))
	assert_that(ScoreSequence.ink_of(cut)).is_equal(ScreenKit.LOSS)


func test_the_table_waits_for_the_sequence_and_a_click_hurries_it() -> void:
	var moments: TableMoments = _moments()
	var player: EventPlayer = _events
	var next: Array[int] = [0]
	player.played.connect(
		func(played: RunEvent) -> void:
			if played.type == RunEvent.Type.METER_CHANGED:
				next[0] = Time.get_ticks_msec()
	)
	var event: RunEvent = _scored("34567", ["red_banner", "canteen", "iron_and_coal"])
	var start: int = Time.get_ticks_msec()
	player.push(event)
	player.push(RunEvent.new(RunEvent.Type.METER_CHANGED, Seats.NONE, 1, 0.0, "famine"))
	await await_idle_frame()
	await await_idle_frame()
	assert_bool(moments.sequence.is_running()).is_true()
	var planned: float = ScoreBeats.lay_out(event.steps, 1.0).total()
	# Timed: that the table waits is seen only by giving the next event the time to come.
	await await_millis(200)
	assert_int(next[0]).is_equal(0)
	# A click on the table, clear of the trick and the ledger, hurries the rest.
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(1800, 1000)
	TestInput.push(self, click)
	await _wait_done(moments.sequence)
	var took: float = (Time.get_ticks_msec() - start) / 1000.0
	assert_float(took).is_less(planned)
	while next[0] == 0 and Time.get_ticks_msec() - start < 5000:
		await await_idle_frame()
	assert_int(next[0]).is_greater(0)


func test_sitting_out_plays_a_villagers_score_at_the_hurried_pace() -> void:
	var moments: TableMoments = _moments()
	# A Cadre never scores for an opponent (ADR 0039), so the villager's play here
	# is the holder's scored play at the villager's seat: the same steps to act out.
	var event: RunEvent = _scored("999", ["canteen"], HOLDER)
	event.seat = 1
	var full: float = moments.sequence.play(event, 1.0)
	moments.sequence.stop()
	moments.sequence.hurrying_villagers = true
	var hurried: float = moments.sequence.play(event, 1.0)
	assert_float(hurried).is_equal_approx(full * UiMotion.PRESETS.score_hurried, 0.01)
	moments.sequence.stop()
	# The player's own play is never hurried for it.
	var own: RunEvent = _scored("999", ["canteen"], HOLDER)
	assert_float(moments.sequence.play(own, 1.0)).is_equal_approx(full, 0.01)
	moments.sequence.stop()


func test_the_pace_scales_it_and_a_long_chain_speeds_up_within_its_cap() -> void:
	var event: RunEvent = _scored("555", ["red_banner", "canteen"])
	var standard: float = ScoreBeats.lay_out(event.steps, 1.0).total()
	assert_float(ScoreBeats.lay_out(event.steps, 0.7).total()).is_equal_approx(
		standard * 0.7, 0.001
	)
	var one: Array[ScoreStep] = []
	var ten: Array[ScoreStep] = []
	for count: int in [1, 10]:
		var steps: Array[ScoreStep] = one if count == 1 else ten
		for _index: int in count:
			steps.append(
				ScoreStep.new(
					ScoreStep.Figure.GRAIN,
					ScoreStep.Source.MODIFIER,
					ScoreStep.Op.ADD,
					5.0,
					0.0,
					5.0
				)
			)
	var base: float = ScoreBeats.lay_out([], 1.0).total()
	var single: float = ScoreBeats.lay_out(one, 1.0).total() - base
	var chain: float = ScoreBeats.lay_out(ten, 1.0).total() - base
	assert_float(chain).is_less(single * 6.0)
	var many: Array[ScoreStep] = []
	for _index: int in 40:
		many.append(ten[0])
	assert_float(ScoreBeats.lay_out(many, 1.0).total()).is_less_equal(
		UiMotion.PRESETS.score_most + 0.001
	)


func test_reduced_motion_keeps_every_tag_figure_and_sound_and_moves_nothing() -> void:
	Settings.set_value("reduced_motion", true)
	var moments: TableMoments = _moments()
	# A Quota of 10 makes any play a big one, which lands with the heavy stamp.
	moments.on_event(RunEvent.new(RunEvent.Type.SET_STARTED, Seats.NONE, 0, 10.0))
	var event: RunEvent = _scored("555", ["red_banner", "canteen", "ration_cut"])
	var tags: Array[String] = []
	var moved: Array[bool] = [false]
	var rest: Vector2 = Vector2.ZERO
	moments.sequence.beat_began.connect(
		func(_kind: int, _at: int) -> void:
			for label: Label in moments.fx.shown_tags():
				if not tags.has(label.text):
					tags.append(label.text)
	)
	moments.on_event(event)
	rest = moments.tally.position
	# The sequence runs, so the frames below are watched while it does.
	assert_bool(moments.sequence.is_running()).is_true()
	while moments.sequence.is_running():
		for tile: Control in moments.tally.find_children("*", "PanelContainer", false, false):
			moved[0] = moved[0] or tile.scale != Vector2.ONE
		moved[0] = moved[0] or moments.tally.position != rest
		await await_idle_frame()
	Settings.set_value("reduced_motion", false)
	assert_bool(moved[0]).is_false()
	var changes: int = 0
	for each: ScoreStep in event.steps:
		changes += 0 if _is_base(each) else 1
	assert_int(tags.size()).is_equal(changes)
	assert_str(Audio.last_played).is_equal(AudioEvents.SCORE_LAND_HEAVY)
	assert_str(moments.tally.shown()).ends_with(Strings.score(event.amount))


## The steps that build the score before anything changes it, which take no tag: the
## cards' printed Grain, the hand's Rate and Zeal's start.
func _is_base(step: ScoreStep) -> bool:
	var base: Array[ScoreStep.Source] = [
		ScoreStep.Source.CARD, ScoreStep.Source.HAND, ScoreStep.Source.START
	]
	return base.has(step.source)
