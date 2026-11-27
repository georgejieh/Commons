extends GdUnitTestSuite
## The arrival played whole with its authored inputs (ADR 0026): through the run
## controller and the director, every step takes exactly its one action and refuses a
## wrong one, no scripted villager move is refused, the player goes out first as a
## peasant and then as landlord, Famine and Denunciation each change once, and both
## purchases happen. A tutorial run writes no save and no profile.

static var _save_path: String = TestFolder.of("test_tutorial_run") + "run.json"

var _controller: RunController
var _director: TutorialDirector
## The screen the test stands on, as the app would show it.
var _screen: String = "table"


func before_test() -> void:
	Saves.use_run_path(_save_path)
	Saves.run_service().delete()
	Saves.profile_service().delete()
	_controller = auto_free(RunController.new())
	add_child(_controller)
	assert_bool(_controller.start(RunStarter.tutorial())).is_true()
	_director = TutorialDirector.new()
	_screen = "table"


func after_test() -> void:
	Saves.run_service().delete()
	Saves.profile_service().delete()


func _loop() -> RunLoop:
	return _controller.run_loop()


## Reports the screen the run now shows, as a settled screen would.
func _report() -> void:
	match _controller.awaiting():
		RunController.AWAIT_SET_OVER:
			_screen = "set_summary"
		RunController.AWAIT_STORE:
			if _screen != "black_market":
				_screen = "store"
		_:
			_screen = "table"
	_director.ready(_screen, _controller.awaiting())


## A wrong action of another kind than the step's, which must be refused.
func _wrong(step: TutorialStep) -> Array:
	var wrong: Dictionary[TutorialStep.Action, Array] = {
		TutorialStep.Action.PASS: ["hint", null],
		TutorialStep.Action.BID_CALL: [TutorialDirector.BID_PASS, null],
		TutorialStep.Action.BID_PASS: [TutorialDirector.BID_CALL, null],
		TutorialStep.Action.NEED: [TutorialDirector.NEED, step.need + 5],
		TutorialStep.Action.BUTTON: ["reroll" if step.button == "buy" else "leave", step.slot],
	}
	if step.action == TutorialStep.Action.PLAY:
		if step.cards.size() > 1:
			return [TutorialDirector.PLAY, [step.cards[0]]]
		return [TutorialDirector.PASS, null]
	return wrong[step.action]


## Sends the step's action to the run, as its screen would after the director took it.
func _act(step: TutorialStep) -> void:
	var ids: Array[int] = []
	ids.assign(Array(step.cards))
	match step.action:
		TutorialStep.Action.BID_CALL:
			assert_int(_controller.bid(true)).is_equal(RunController.OK)
		TutorialStep.Action.BID_PASS:
			assert_int(_controller.bid(false)).is_equal(RunController.OK)
		TutorialStep.Action.PLAY:
			assert_int(_controller.play(ids)).is_equal(RunController.OK)
		TutorialStep.Action.PASS:
			assert_int(_controller.pass_turn()).is_equal(RunController.OK)
		TutorialStep.Action.NEED:
			assert_int(_controller.declare_need(step.need)).is_equal(RunController.OK)
		TutorialStep.Action.BUTTON:
			_press(step)


func _press(step: TutorialStep) -> void:
	match step.button:
		"continue":
			assert_int(_controller.finish_set()).is_equal(RunController.OK)
		"buy":
			assert_int(_controller.buy(step.slot)).is_equal(RunController.OK)
		"plot_card":
			assert_int(_controller.plot_card(step.slot)).is_equal(RunController.OK)


func _detail(step: TutorialStep) -> Variant:
	match step.action:
		TutorialStep.Action.PLAY:
			return Array(step.cards)
		TutorialStep.Action.NEED:
			return step.need
	return step.slot


func _action_name(step: TutorialStep) -> String:
	match step.action:
		TutorialStep.Action.BID_CALL:
			return TutorialDirector.BID_CALL
		TutorialStep.Action.BID_PASS:
			return TutorialDirector.BID_PASS
		TutorialStep.Action.PLAY:
			return TutorialDirector.PLAY
		TutorialStep.Action.PASS:
			return TutorialDirector.PASS
		TutorialStep.Action.NEED:
			return TutorialDirector.NEED
	return step.button


## Plays every step and returns the run's events.
func _play_through() -> Array[RunEvent]:
	var events: Array[RunEvent] = []
	_controller.event_emitted.connect(func(event: RunEvent) -> void: events.append(event))
	_report()
	var guard: int = 0
	while _director.phase() != TutorialDirector.Phase.DONE and guard < 100:
		guard += 1
		var step: TutorialStep = _director.step()
		assert_int(_director.phase()).override_failure_message("step %s" % step.id).is_equal(
			TutorialDirector.Phase.PROMPT
		)
		var wrong: Array = _wrong(step)
		var was: int = _controller.awaiting()
		assert_bool(_director.attempt(wrong[0], wrong[1])).is_false()
		assert_int(_controller.awaiting()).is_equal(was)
		if not step.via.is_empty():
			assert_bool(_director.attempt(step.via)).is_true()
			_screen = "black_market"
			_report()
		assert_bool(_director.attempt(_action_name(step), _detail(step))).is_true()
		_act(step)
		_director.note(step.until)
		_director.release()
		_report()
	return events


func test_the_arrival_plays_through_with_its_authored_inputs() -> void:
	var events: Array[RunEvent] = _play_through()
	assert_int(_director.phase()).is_equal(TutorialDirector.Phase.DONE)
	assert_int(_director.index()).is_equal(20)
	assert_int(_loop().refused_bot_actions).is_equal(0)
	assert_int(_loop().tutorial.faults).is_equal(0)
	var landlords: Array[int] = []
	var first_out: Array[int] = []
	var meters: Dictionary[String, int] = {}
	for event: RunEvent in events:
		if event.type == RunEvent.Type.LANDLORD_CHOSEN:
			landlords.append(event.seat)
		elif event.type == RunEvent.Type.METER_CHANGED:
			meters[event.text] = int(meters.get(event.text, 0)) + 1
		elif event.type == RunEvent.Type.ROUND:
			if event.round_event.type == RoundEvent.Type.ROUND_ENDED:
				first_out.append(event.round_event.seat)
	assert_array(landlords).is_equal([2, 0])
	assert_array(first_out).is_equal([0, 0])
	assert_dict(meters).is_equal({"famine": 1, "denunciation": 1})
	var state: RunState = _controller.state_copy()
	assert_array(state.inventory.cadres).is_equal(["iron_rice_bowl"])
	assert_int(state.inventory.plot.size()).is_equal(1)
	assert_int(state.inventory.plot[0].base_rank()).is_equal(Ranks.TEN)
	assert_int(state.inventory.plot[0].suit()).is_equal(1)
	assert_bool(FileAccess.file_exists(Saves.run_service().path())).is_false()
	assert_bool(ProfileSeen.exists(Saves.profile_service())).is_false()


func test_the_audit_shows_the_authored_faces() -> void:
	var events: Array[RunEvent] = _play_through()
	var faces: Array[int] = []
	for event: RunEvent in events:
		if event.type == RunEvent.Type.AUDIT_ROLLED:
			faces.append(event.value)
	assert_array(faces).is_equal([1, 4, 5, 3])


func test_a_wrong_scripted_move_is_a_fault_and_falls_back_to_a_legal_one() -> void:
	var seat: TutorialSeat = TutorialSeat.new()
	# Three 7s where only a single is legal, then nothing left for the next turn.
	seat.plays.append(PackedInt32Array([17, 18, 19]))
	var faults: Array[int] = [0]
	var villager: ScriptedVillager = ScriptedVillager.new(2)
	villager.on_fault = func() -> void: faults[0] += 1
	villager.start(seat)
	var none: Array[PublicPlay] = []
	var no_kitty: Array[CardInstance] = []
	var deck: Deck = Deck.new()
	var cards: Array[CardInstance] = [deck.card(17), deck.card(18), deck.card(19)]
	var sizes: PackedInt32Array = PackedInt32Array([17, 17, 20])
	var leading: PublicView = PublicView.new(2, 2, sizes, none, no_kitty, null, PackedInt32Array())
	var counts: PackedByteArray = CardSelection.printed_counts(cards)
	var view: SeatView = SeatView.new(2, leading, counts, cards, deck.rank_counts())
	var single: Pattern = Pattern.new(Pattern.Type.SINGLE, Ranks.SEVEN, 1, 1, PackedByteArray(), 4)
	var legal: Array[Pattern] = [single]
	var answer: BotPlay = villager.play(view, legal)
	assert_int(faults[0]).is_equal(1)
	assert_bool(answer.pattern.equals(single)).is_true()
	answer = villager.play(view, legal)
	assert_int(faults[0]).is_equal(2)
	assert_bool(answer.pattern.equals(single)).is_true()
	assert_bool(villager.bid()).is_false()
	assert_int(faults[0]).is_equal(3)


func test_a_fault_counts_as_a_refused_bot_action_in_the_run() -> void:
	var loop: RunLoop = _loop()
	var was: int = loop.refused_bot_actions
	loop.tutorial.on_fault.call()
	assert_int(loop.refused_bot_actions).is_equal(was + 1)
