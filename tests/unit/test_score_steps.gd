extends GdUnitTestSuite
## What changed a play's score, recorded step by step for the table to act out.
## Recording never changes a score: every golden hand scores the same with it on, under
## every modifier there is. The steps, applied in order, give the play's Grain, Rate and
## Zeal, and their product with the Total steps gives its total. Each step names what made
## it; the cards come first, then the hand's Rate and Zeal, then the rest in hook order.
## Every seat's real play carries its steps on PLAY_SCORED; a preview records none.

const MODIFIERS: String = "res://data/modifiers"
const HANDS: Array[String] = [
	"9",
	"99",
	"999",
	"9993",
	"99933",
	"34567",
	"334455",
	"333444",
	"33344456",
	"3334445566",
	"999945",
	"99994455",
	"9999",
	"sb",
]
const HOLDER: int = 0
const CLOSE: float = 0.0001


func _def(id: String) -> ModifierDef:
	return ResourceLoader.load("%s/%s.tres" % [MODIFIERS, id])


## Every modifier that can sit in the stack while a play is scored.
func _scoring_ids() -> Array[String]:
	var ids: Array[String] = []
	for file: String in DirAccess.get_files_at(MODIFIERS):
		if file.get_extension() != "tres":
			continue
		var definition: ModifierDef = ResourceLoader.load(MODIFIERS.path_join(file)) as ModifierDef
		if definition == null:
			continue
		var hooks: Array[String] = [Hooks.PLAY_SCORED, Hooks.CARD_SCORED]
		if definition.hooks.has(hooks[0]) or definition.hooks.has(hooks[1]):
			ids.append(definition.id)
	return ids


func _hand(text: String) -> Array[CardInstance]:
	return RoundScript.stacked_deal([text], "").hands[0].cards()


func _pattern(cards: Array[CardInstance]) -> Pattern:
	var rules: RuleSet = RuleSet.default_rules()
	return RoundScript.classify(cards, rules, Ranks.identity_map()).pattern


func _score(
	stack: ModifierStack, cards: Array[CardInstance], level: int, record: bool, seat: int = HOLDER
) -> ScoreBreakdown:
	var plays: PackedInt32Array = PackedInt32Array([1, 2, 0])
	var grain: PackedFloat64Array = PackedFloat64Array([30.0, 40.0, 0.0])
	var facts: PlayFacts = PlayFacts.new(2, 3, plays, grain, 3)
	return Scorer.score_play(
		cards, _pattern(cards), level, seat, false, stack, Scorer.DEFAULT_PARAMS, 1, facts, record
	)


## Applies a play's steps in order and returns its Grain, Rate, Zeal and total.
static func composed(steps: Array[ScoreStep]) -> PackedFloat64Array:
	var figures: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
	for step: ScoreStep in steps:
		if step.figure != ScoreStep.Figure.TOTAL:
			figures[step.figure] = ScoreStep.applied(step.op, figures[step.figure], step.value)
	figures[3] = figures[0] * figures[1] * figures[2]
	for step: ScoreStep in steps:
		if step.figure == ScoreStep.Figure.TOTAL:
			figures[3] = ScoreStep.applied(step.op, figures[3], step.value)
	return figures


func _check(breakdown: ScoreBreakdown, where: String) -> void:
	var figures: PackedFloat64Array = composed(breakdown.trail)
	var wanted: Array[float] = [breakdown.grain, breakdown.rate, breakdown.zeal, breakdown.total]
	for index: int in wanted.size():
		var tolerance: float = maxf(CLOSE, absf(wanted[index]) * 1e-9)
		(
			assert_float(figures[index])
			. override_failure_message("%s figure %d: %s" % [where, index, figures])
			. is_equal_approx(wanted[index], tolerance)
		)
	# Each step starts where the step before it on its figure left off.
	var last: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
	for step: ScoreStep in breakdown.trail:
		if step.figure == ScoreStep.Figure.TOTAL:
			continue
		var from: float = last[step.figure]
		assert_float(step.before).override_failure_message(where).is_equal_approx(from, CLOSE)
		last[step.figure] = step.after


func test_recording_changes_no_golden_score() -> void:
	var stack: ModifierStack = ModifierStack.new()
	for text: String in HANDS:
		var cards: Array[CardInstance] = _hand(text)
		var plain: ScoreBreakdown = Scorer.score_play(cards, _pattern(cards), 1, 0, false, stack)
		var kept: ScoreBreakdown = Scorer.score_play(
			cards, _pattern(cards), 1, 0, false, stack, Scorer.DEFAULT_PARAMS, 0, null, true
		)
		assert_float(kept.total).is_equal(plain.total)
		assert_float(kept.grain).is_equal(plain.grain)
		assert_array(plain.trail).is_empty()
		_check(kept, text)


func test_every_modifier_scores_the_same_recorded_and_its_steps_add_up() -> void:
	var ids: Array[String] = _scoring_ids()
	assert_int(ids.size()).is_greater(10)
	for id: String in ids:
		for seat: int in [HOLDER, 1]:
			var stack: ModifierStack = ModifierStack.new()
			stack.add(_def(id), HOLDER)
			for text: String in HANDS:
				for level: int in [1, 3]:
					var cards: Array[CardInstance] = _hand(text)
					var plain: ScoreBreakdown = _score(stack, cards, level, false, seat)
					var kept: ScoreBreakdown = _score(stack, cards, level, true, seat)
					var where: String = "%s seat %d %s level %d" % [id, seat, text, level]
					assert_float(kept.total).override_failure_message(where).is_equal(plain.total)
					_check(kept, where)


func test_stacked_modifiers_still_add_up_in_hook_order() -> void:
	var ids: Array[String] = [
		"red_banner",
		"poor_peasants_association",
		"canteen",
		"last_sheaf",
		"slogan_of_the_week",
		"iron_rice_bowl",
		"ration_cut",
		"show_trial",
		"morning_meeting"
	]
	var stack: ModifierStack = ModifierStack.new()
	for id: String in ids:
		stack.add(_def(id), HOLDER)
	for text: String in HANDS:
		var cards: Array[CardInstance] = _hand(text)
		var kept: ScoreBreakdown = _score(stack, cards, 2, true)
		assert_float(kept.total).is_equal(_score(stack, cards, 2, false).total)
		_check(kept, text)


func test_the_cards_come_first_then_rate_and_zeal_then_what_changed_them() -> void:
	var stack: ModifierStack = ModifierStack.new()
	stack.add(_def("red_banner"), HOLDER)
	stack.add(_def("canteen"), HOLDER)
	var cards: Array[CardInstance] = [
		Deck.new().card(Ranks.FIVE * Deck.SUITS),
		Deck.new().card(Ranks.FIVE * Deck.SUITS + 1),
		Deck.new().card(Ranks.FIVE * Deck.SUITS + 2),
	]
	CardModifiers.enhance(cards[2], CardInstance.MODEL)
	var kept: ScoreBreakdown = _score(stack, cards, 2, true)
	var sources: Array[int] = []
	for step: ScoreStep in kept.trail:
		sources.append(step.source)
	var card: int = ScoreStep.Source.CARD
	assert_array(sources.slice(0, 5)).is_equal(
		[card, card, card, ScoreStep.Source.HAND, ScoreStep.Source.START]
	)
	assert_int(sources[5]).is_equal(ScoreStep.Source.LEVEL)
	var named: Array[String] = []
	for step: ScoreStep in kept.trail.slice(6):
		named.append(step.source_id)
	# Card by card, Red Banner on the heart and the Model card's mark, then Canteen's Zeal
	# for the trio.
	assert_array(named).is_equal(["red_banner", CardInstance.MODEL, "canteen"])
	assert_int(kept.trail[6].card_id).is_equal(cards[1].id())
	assert_int(kept.trail[7].card_id).is_equal(cards[2].id())
	assert_int(kept.trail[8].figure).is_equal(ScoreStep.Figure.ZEAL)
	assert_int(kept.trail[8].modifier_kind).is_equal(ModifierDef.Kind.CADRE)


func test_a_cut_is_marked_as_one() -> void:
	var stack: ModifierStack = ModifierStack.new()
	stack.add(_def("morning_meeting"), HOLDER)
	stack.add(_def("ration_cut"), HOLDER)
	for text: String in HANDS:
		for step: ScoreStep in _score(stack, _hand(text), 1, true).trail:
			if step.source == ScoreStep.Source.MODIFIER:
				assert_bool(step.is_cut()).override_failure_message(step.source_id).is_true()


func test_every_seats_real_play_carries_its_steps() -> void:
	var loop: RunLoop = RunLoop.new(RunState.new(4719), RunScript.bots(), SetConfig.new())
	loop.start_set()
	RunScript.new().play_until_set_over(loop)
	var seen: Array[int] = []
	for event: RunEvent in loop.set_log.events():
		if event.type != RunEvent.Type.PLAY_SCORED:
			continue
		if not seen.has(event.seat):
			seen.append(event.seat)
		assert_array(event.steps).is_not_empty()
		var figures: PackedFloat64Array = composed(event.steps)
		assert_float(figures[0]).is_equal_approx(event.grain, CLOSE)
		assert_float(figures[3]).is_equal_approx(event.amount, maxf(CLOSE, event.amount * 1e-9))
	assert_int(seen.size()).is_equal(Seats.COUNT)
