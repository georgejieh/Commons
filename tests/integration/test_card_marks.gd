extends GdUnitTestSuite
## ADR 0021: an owner's stamp and the Model mark are saved per deck card and put back on
## every deal, through a whole Set, a save and a load, and a replay; a plot card keeps
## its own marks, in the plot and in the hand it is swapped into for a round, and a deck
## card a swap sets aside keeps its saved marks for the next deal (ADR 0038). A Model card
## doubles its Grain for whoever scores it, never as a kicker, and a stamped card scores
## Red Ink's Grain only for its owner and breeds Resentment when the owner scores it.

const RED_INK: ModifierDef = preload("res://data/modifiers/red_ink.tres")
const SEED: int = 5101
const STAMPED: Array[int] = [0, 13, 27, 40, 52]
const MODELS: Array[int] = [3, 17, 30, 44, 53]
const DECK_SIZE: int = 54


## A run whose saved marks stamp some deck cards as the player's and make others Model.
func _marked_state(seed_value: int = SEED) -> RunState:
	var state: RunState = RunState.new(seed_value)
	for deck_id: int in STAMPED:
		CardMarks.stamp(state, Deck.new().card(deck_id), RunLoop.PLAYER)
	for deck_id: int in MODELS:
		CardMarks.enhance(state, Deck.new().card(deck_id), CardInstance.MODEL)
	return state


## Every card still held, by ID, across the three seats.
func _held(loop: RunLoop) -> Dictionary[int, CardInstance]:
	var held: Dictionary[int, CardInstance] = {}
	for seat: int in Seats.COUNT:
		for card: CardInstance in loop.round_state().view_for(seat).own_cards:
			held[card.id()] = card
	return held


## Every held deck card carries exactly the marks the run saved for it.
func _check_marks(loop: RunLoop) -> void:
	var marks: CardMarks = loop.state.card_marks
	var held: Dictionary[int, CardInstance] = _held(loop)
	for card_id: int in held:
		var card: CardInstance = held[card_id]
		if card.origin() != CardInstance.Origin.DECK:
			continue
		var stamp: int = marks.stamps.get(card_id, CardInstance.NO_OWNER)
		var enhancement: String = marks.enhancements.get(card_id, CardInstance.NO_ID)
		assert_int(card.owner_stamp()).override_failure_message("stamp %d" % card_id).is_equal(
			stamp
		)
		assert_str(card.enhancement_id()).override_failure_message("model %d" % card_id).is_equal(
			enhancement
		)


func _check_conserved(loop: RunLoop) -> void:
	var ids: Array[int] = []
	for seat: int in Seats.COUNT:
		for card: CardInstance in loop.round_state().view_for(seat).own_cards:
			ids.append(card.id())
	assert_int(ids.size()).is_equal(DECK_SIZE)
	assert_int(_held(loop).size()).is_equal(DECK_SIZE)
	for card: CardInstance in loop.state.inventory.plot:
		assert_bool(ids.has(card.id())).is_false()


func _to_play(loop: RunLoop, script: RunScript) -> void:
	while loop.awaiting() != RunLoop.Awaiting.PLAYER_PLAY:
		assert_bool(script.act(loop)).is_true()


## With a marked plot swapping every round: before each round's first play, the 54 cards
## held are all different and none is in the plot, so no card is made or lost.
func test_marks_survive_every_deal_of_a_whole_set() -> void:
	var state: RunState = _marked_state()
	for index: int in 2:
		var plot_card: CardInstance = CardInstance.new(
			state.take_plot_id(), Ranks.NINE, index, CardInstance.Origin.PLOT
		)
		CardMarks.enhance(state, plot_card, CardInstance.MODEL)
		state.inventory.plot.append(plot_card)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots())
	var script: RunScript = RunScript.new()
	loop.start_set()
	var deals: int = 0
	while loop.awaiting() != RunLoop.Awaiting.SET_OVER:
		if loop.awaiting() == RunLoop.Awaiting.PLAYER_SWAP:
			deals += 1
			_check_conserved(loop)
		if loop.round_state() != null:
			_check_marks(loop)
		if not script.act(loop):
			break
	assert_int(deals).is_greater(1)
	# A swap moves no mark: every saved mark is still saved, and no other.
	assert_int(loop.state.card_marks.stamps.size()).is_equal(STAMPED.size())
	assert_int(loop.state.card_marks.enhancements.size()).is_equal(MODELS.size())
	for card_id: int in loop.state.card_marks.stamps:
		assert_array(STAMPED).contains([card_id])
	for card_id: int in loop.state.card_marks.enhancements:
		assert_array(MODELS).contains([card_id])
	assert_int(loop.state.card_marks.stamps.size()).is_greater(0)


func test_marks_survive_a_save_a_load_and_a_replay() -> void:
	var service: SaveService = SaveService.for_run(TestFolder.of("test_card_marks") + "run.json")
	service.delete()
	var loop: RunLoop = RunLoop.new(_marked_state(), RunScript.bots())
	var script: RunScript = RunScript.new()
	loop.start_set()
	_to_play(loop, script)
	script.act(loop)
	_to_play(loop, script)
	assert_int(service.save(loop.record.to_dict())).is_equal(OK)
	var loaded: SaveLoad = service.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.OK)
	var saved: RunState = RunState.from_dict(loaded.data["checkpoint"])
	assert_dict(saved.card_marks.stamps).is_equal(loop.state.card_marks.stamps)
	assert_dict(saved.card_marks.enhancements).is_equal(loop.state.card_marks.enhancements)
	var resumed: RunLoop = RunRecord.resume(loaded.data, RunScript.bots())
	assert_object(resumed).is_not_null()
	assert_int(resumed.awaiting()).is_equal(RunLoop.Awaiting.PLAYER_PLAY)
	_check_marks(resumed)
	var mine: Array[int] = []
	for card: CardInstance in resumed.player_cards():
		mine.append(card.id())
	var expected: Array[int] = []
	for card: CardInstance in loop.player_cards():
		expected.append(card.id())
	assert_array(mine).is_equal(expected)
	service.delete()


## A stamp or Model mark set mid-Set on a deck card is saved and reaches the next deal.
func test_a_card_marked_mid_set_keeps_its_marks_next_round() -> void:
	var state: RunState = RunState.new(SEED)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots())
	var script: RunScript = RunScript.new()
	loop.start_set()
	_to_play(loop, script)
	var card: CardInstance = loop.player_cards()[0]
	CardMarks.enhance(state, card, CardInstance.MODEL)
	CardMarks.stamp(state, card, RunLoop.PLAYER)
	assert_str(card.enhancement_id()).is_equal(CardInstance.MODEL)
	var round_index: int = state.round_index
	while state.round_index == round_index and loop.awaiting() != RunLoop.Awaiting.SET_OVER:
		script.act(loop)
	if loop.awaiting() == RunLoop.Awaiting.SET_OVER:
		RunScript.next_set(loop)
	_to_play(loop, script)
	var dealt: CardInstance = _held(loop)[card.id()]
	assert_str(dealt.enhancement_id()).is_equal(CardInstance.MODEL)
	assert_int(dealt.owner_stamp()).is_equal(RunLoop.PLAYER)


func test_a_plot_card_saves_its_own_marks() -> void:
	var state: RunState = RunState.new(SEED)
	var plot_card: CardInstance = CardInstance.new(
		state.take_plot_id(), Ranks.NINE, 0, CardInstance.Origin.PLOT
	)
	state.inventory.plot.append(plot_card)
	# Marked through another copy, as a view would hold: the plot's own card changes.
	var copy: CardInstance = plot_card.snapshot()
	CardMarks.enhance(state, copy, CardInstance.MODEL)
	CardMarks.stamp(state, copy, RunLoop.PLAYER)
	assert_str(plot_card.enhancement_id()).is_equal(CardInstance.MODEL)
	assert_int(plot_card.owner_stamp()).is_equal(RunLoop.PLAYER)
	assert_bool(state.card_marks.stamps.is_empty()).is_true()
	var saved: RunState = RunState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_str(saved.inventory.plot[0].enhancement_id()).is_equal(CardInstance.MODEL)
	assert_int(saved.inventory.plot[0].owner_stamp()).is_equal(RunLoop.PLAYER)


## A marked plot card swapped into the hand keeps its marks there and in the plot, which
## the swap leaves as it was; the marked deck card it replaced sits the round out and is
## dealt with its marks the next round (ADR 0038). No card is created, lost or repeated.
func test_a_swap_keeps_marks_both_ways() -> void:
	var state: RunState = RunState.new(SEED)
	for deck_id: int in DECK_SIZE:
		CardMarks.stamp(state, Deck.new().card(deck_id), RunLoop.PLAYER)
		CardMarks.enhance(state, Deck.new().card(deck_id), CardInstance.MODEL)
	var plot_card: CardInstance = CardInstance.new(
		state.take_plot_id(), Ranks.NINE, 1, CardInstance.Origin.PLOT
	)
	CardMarks.stamp(state, plot_card, RunLoop.PLAYER)
	CardMarks.enhance(state, plot_card, CardInstance.MODEL)
	state.inventory.plot.append(plot_card)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots())
	var script: RunScript = RunScript.new()
	loop.start_set()
	while loop.awaiting() != RunLoop.Awaiting.PLAYER_SWAP:
		assert_bool(script.act(loop)).is_true()
	var given: CardInstance = loop.player_cards()[0]
	var taken: int = plot_card.id()
	assert_int(loop.player_swap([given.id()], [taken])).is_equal(RunLoop.Reason.OK)
	assert_int(state.inventory.plot.size()).is_equal(1)
	var stored: CardInstance = state.inventory.plot[0]
	assert_object(stored).is_same(plot_card)
	assert_str(stored.enhancement_id()).is_equal(CardInstance.MODEL)
	assert_int(stored.owner_stamp()).is_equal(RunLoop.PLAYER)
	assert_bool(state.card_marks.stamps.has(given.id())).is_true()
	assert_bool(state.card_marks.enhancements.has(given.id())).is_true()
	var arrived: CardInstance = null
	for card: CardInstance in loop.player_cards():
		arrived = card if card.id() == taken else arrived
	assert_str(arrived.enhancement_id()).is_equal(CardInstance.MODEL)
	assert_int(arrived.owner_stamp()).is_equal(RunLoop.PLAYER)
	assert_bool(_held(loop).has(given.id())).is_false()
	# Next round the given card is dealt again with its marks, and the plot card is home.
	var round_index: int = state.round_index
	while state.round_index == round_index and loop.awaiting() != RunLoop.Awaiting.SET_OVER:
		script.act(loop)
	if loop.awaiting() == RunLoop.Awaiting.SET_OVER:
		RunScript.next_set(loop)
	while loop.round_state() == null or loop.awaiting() == RunLoop.Awaiting.PLAYER_BID:
		assert_bool(script.act(loop)).is_true()
	var next: Dictionary[int, CardInstance] = _held(loop)
	assert_bool(next.has(given.id())).is_true()
	assert_bool(next.has(taken)).is_false()
	assert_str(next[given.id()].enhancement_id()).is_equal(CardInstance.MODEL)
	assert_int(next[given.id()].owner_stamp()).is_equal(RunLoop.PLAYER)
	assert_object(state.inventory.plot[0]).is_same(plot_card)
	_check_marks(loop)


## A Single of the deck card's rank.
func _single(deck_id: int) -> Pattern:
	var counts: PackedByteArray = PackedByteArray()
	counts.resize(Ranks.COUNT)
	counts[Deck.new().rank_of(deck_id)] = 1
	var rules: RuleSet = RuleSet.default_rules()
	return Classifier.classify(counts, rules, Ranks.identity_map()).pattern


func test_a_model_card_doubles_its_grain_for_whoever_scores_it() -> void:
	var stack: ModifierStack = ModifierStack.new()
	var params: ScoreParams = Scorer.DEFAULT_PARAMS
	assert_int(params.model_grain_percent).is_equal(200)
	var pattern: Pattern = _single(20)
	var plain: Array[CardInstance] = [Deck.new().card(20)]
	var model: Array[CardInstance] = [Deck.new().card(20)]
	CardModifiers.enhance(model[0], CardInstance.MODEL)
	var base: float = Scorer.score_play(plain, pattern, 1, 0, false, stack).grain
	for seat: int in Seats.COUNT:
		var scored: ScoreBreakdown = Scorer.score_play(model, pattern, 1, seat, false, stack)
		assert_float(scored.grain).is_equal(base * 2.0)


## Dealt to an opponent, the player's Model card doubles for the opponent, through the
## loop's own scoring.
func test_a_model_card_dealt_to_an_opponent_doubles_for_them() -> void:
	var state: RunState = RunState.new(SEED)
	for deck_id: int in DECK_SIZE:
		CardMarks.enhance(state, Deck.new().card(deck_id), CardInstance.MODEL)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots())
	var script: RunScript = RunScript.new()
	loop.start_set()
	var checked: int = 0
	var seen: int = 0
	while loop.awaiting() != RunLoop.Awaiting.SET_OVER and checked < 6:
		if not script.act(loop):
			break
		var events: Array[RunEvent] = loop.events()
		for index: int in range(seen, events.size()):
			if events[index].type != RunEvent.Type.PLAY_SCORED or events[index].seat == 0:
				continue
			var played: RoundEvent = events[index - 1].round_event
			var grain: float = 0.0
			var body: Array[bool] = Scorer.body_flags(played.cards, played.pattern)
			for at: int in played.cards.size():
				if body[at]:
					grain += Scorer.DEFAULT_PARAMS.card_grain[played.cards[at].base_rank()]
			assert_float(events[index].grain).is_equal(grain * 2.0)
			checked += 1
		seen = events.size()
	assert_int(checked).is_greater(0)


func test_a_model_kicker_still_scores_nothing() -> void:
	var stack: ModifierStack = ModifierStack.new()
	var cards: Array[CardInstance] = RoundScript.stacked_deal(["7773"], "").hands[0].cards()
	var counts: PackedByteArray = RankText.counts("7773")
	var pattern: Pattern = (
		Classifier.classify(counts, RuleSet.default_rules(), Ranks.identity_map()).pattern
	)
	var plain: float = Scorer.score_play(cards, pattern, 1, 0, false, stack).total
	var body: Array[bool] = Scorer.body_flags(cards, pattern)
	for at: int in cards.size():
		if not body[at]:
			CardModifiers.enhance(cards[at], CardInstance.MODEL)
	assert_float(Scorer.score_play(cards, pattern, 1, 0, false, stack).total).is_equal(plain)


## Red Ink, held by the player, reads stamps that a deal put back on: the player's
## stamped card scores its Grain for the player and is plain for anyone else.
func test_red_ink_reads_a_saved_stamp_only_for_its_owner() -> void:
	var state: RunState = RunState.new(SEED)
	CardMarks.stamp(state, Deck.new().card(20), RunLoop.PLAYER)
	var dealt: Array[CardInstance] = [Deck.new().card(20)]
	state.card_marks.apply(dealt)
	assert_int(dealt[0].owner_stamp()).is_equal(RunLoop.PLAYER)
	var stack: ModifierStack = ModifierStack.new()
	stack.add(RED_INK, RunLoop.PLAYER)
	var plain_stack: ModifierStack = ModifierStack.new()
	var pattern: Pattern = _single(20)
	var plain: float = Scorer.score_play(dealt, pattern, 1, 0, false, plain_stack).grain
	var grain: float = RED_INK.parameters[OwnerStampEffect.GRAIN]
	var mine: float = Scorer.score_play(dealt, pattern, 1, 0, false, stack).grain
	assert_float(mine).is_equal(plain + grain)
	assert_float(Scorer.score_play(dealt, pattern, 1, 1, false, stack).grain).is_equal(plain)


## Each saved stamp the player scores adds Resentment, as a stamp always has.
func test_scoring_saved_stamps_breeds_resentment() -> void:
	var state: RunState = RunState.new(SEED)
	for deck_id: int in DECK_SIZE:
		CardMarks.stamp(state, Deck.new().card(deck_id), RunLoop.PLAYER)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots())
	loop.start_set()
	RunScript.new().play_until_set_over(loop)
	var causes: int = 0
	for summary_event: RunEvent in loop.events():
		if summary_event.type == RunEvent.Type.RESENTMENT:
			if summary_event.text == Resentment.STAMPED_CARD:
				causes += 1
	assert_int(causes).is_greater(0)
	assert_int(state.resentment).is_greater(0)


func test_saved_marks_reject_a_damaged_shape() -> void:
	var good: Dictionary = _marked_state().card_marks.to_dict()
	assert_bool(CardMarks.is_valid(JSON.parse_string(JSON.stringify(good)))).is_true()
	assert_bool(CardMarks.is_valid([])).is_false()
	assert_bool(CardMarks.is_valid({"stamps": {}})).is_false()
	assert_bool(CardMarks.is_valid({"stamps": {"x": 0}, "enhancements": {}})).is_false()
	assert_bool(CardMarks.is_valid({"stamps": {"3": "a"}, "enhancements": {}})).is_false()
	assert_bool(CardMarks.is_valid({"stamps": {}, "enhancements": {"3": 1}})).is_false()
