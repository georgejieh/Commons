extends GdUnitTestSuite
## The enhancements on a card's face and at the table (ADR 0041): each draws its own mark,
## of its own kind, where the Model rosette sits, and a card holds one at a time; each has
## a keyword whose meaning quotes the data; and a scored play acts each one out with its
## tag on its card, the Surplus coupon after the score with no figure of its own.

const HOLDER: int = 0
const CARD_SCENE: PackedScene = preload("res://ui/cards/card_view.tscn")


func _view() -> CardView:
	var view: CardView = auto_free(CARD_SCENE.instantiate())
	add_child(view)
	return view


func _card(deck_id: int, enhancement: String) -> CardInstance:
	var card: CardInstance = Deck.new().card(deck_id)
	CardModifiers.enhance(card, enhancement)
	return card


func test_each_enhancement_draws_its_own_mark_and_a_card_shows_one() -> void:
	var view: CardView = _view()
	var kinds: Array[CardMark.Kind] = []
	for enhancement: String in CardInstance.ENHANCEMENTS:
		view.bind(_card(20, enhancement))
		assert_str(view.shown_enhancement()).is_equal(enhancement)
		var badge: CardMark = view.get("_badge")
		assert_bool(kinds.has(badge.kind)).is_false()
		kinds.append(badge.kind)
		assert_vector(badge.position).is_equal(CardView.ENHANCEMENT_AT)
		await await_idle_frame()
	view.bind(Deck.new().card(20))
	assert_str(view.shown_enhancement()).is_empty()


func test_every_mark_draws_at_every_stage_without_error() -> void:
	for kind: int in CardMark.Kind.values():
		var mark: CardMark = auto_free(CardMark.new(kind as CardMark.Kind))
		mark.visible = true
		add_child(mark)
		mark.queue_redraw()
	await await_idle_frame()


func test_each_marks_keyword_quotes_the_data() -> void:
	var params: ScoreParams = Scorer.DEFAULT_PARAMS
	assert_str(Keywords.meaning("sheaf")).contains("+%d Grain" % params.sheaf_grain)
	assert_str(Keywords.meaning("pennant")).contains("+%s Zeal" % Strings.factor(0.2))
	assert_str(Keywords.meaning("surplus")).contains("%d coupons a round" % 2)
	for id: String in ["sheaf", "pennant", "surplus"]:
		assert_bool(Keywords.TERMS.has(id)).is_true()
		assert_bool(Keywords.meaning(id).contains("{")).is_false()
	var found: PackedStringArray = Keywords.found(tr("campaign.surplus_sale.text"))
	assert_bool(found.has("surplus")).is_true()


func test_a_coupon_step_and_a_pennant_step_say_what_they_gave() -> void:
	var coupon: ScoreStep = ScoreStep.new(
		ScoreStep.Figure.COUPONS, ScoreStep.Source.MARK, ScoreStep.Op.ADD, 1.0, 0.0, 1.0
	)
	assert_str(ScoreSequence.tag_text(coupon)).is_equal("+1 " + tr("score.step.coupon"))
	assert_bool(ScoreSequence.ink_of(coupon) == ScreenKit.COUPON).is_true()
	var two: ScoreStep = ScoreStep.new(
		ScoreStep.Figure.COUPONS, ScoreStep.Source.MARK, ScoreStep.Op.ADD, 2.0, 0.0, 2.0
	)
	assert_str(ScoreSequence.tag_text(two)).is_equal("+2 " + tr("score.step.coupons"))
	var zeal: ScoreStep = ScoreStep.new(
		ScoreStep.Figure.ZEAL, ScoreStep.Source.MARK, ScoreStep.Op.ADD, 0.2, 1.0, 1.2
	)
	assert_str(ScoreSequence.tag_text(zeal)).is_equal("+0.2 " + tr("keyword.zeal.name"))


## A play with a Sheaf, a Pennant and a paid Surplus card acts out each mark with its tag
## and lands on its total; the coupon changes no figure on the tally.
func test_a_marked_play_acts_out_each_mark() -> void:
	var moments: TableMoments = auto_free(TableMoments.new())
	var ledger: Ledger = auto_free(Ledger.new())
	var pile: TrickPile = auto_free(TrickPile.new())
	var motion: TableMotion = auto_free(TableMotion.new())
	var player: EventPlayer = auto_free(EventPlayer.new())
	for node: Node in [moments, ledger, pile, motion, player]:
		add_child(node)
	moments.size = Vector2(1920, 1080)
	pile.position = Vector2(470, 380)
	pile.size = Vector2(640, 300)
	var names: Dictionary[int, String] = {0: "You", 1: "Wang", 2: "Zhao"}
	moments.setup(ledger, pile, motion, player, {}, names, {})
	var cards: Array[CardInstance] = [
		_card(Ranks.NINE * Deck.SUITS, CardInstance.SHEAF),
		_card(Ranks.NINE * Deck.SUITS + 1, CardInstance.PENNANT),
		_card(Ranks.NINE * Deck.SUITS + 2, CardInstance.SURPLUS),
	]
	var rules: RuleSet = RuleSet.default_rules()
	var pattern: Pattern = RoundScript.classify(cards, rules, Ranks.identity_map()).pattern
	var score: ScoreBreakdown = Scorer.score_play(
		cards, pattern, 1, HOLDER, false, ModifierStack.new(), Scorer.DEFAULT_PARAMS, 0, null, true
	)
	var state: RunState = RunState.new(1)
	var steps: Array[ScoreStep] = score.trail
	steps.append_array(SurplusPay.new().pay(state, score.surplus_cards, Scorer.DEFAULT_PARAMS))
	var event: RunEvent = RunEvent.new(RunEvent.Type.PLAY_SCORED, HOLDER, 0, score.total)
	event.grain = score.grain
	event.rate = score.rate
	event.zeal = score.zeal
	event.steps = steps
	var tags: Array[String] = []
	moments.sequence.beat_began.connect(
		func(_kind: int, _at: int) -> void:
			for label: Label in moments.fx.shown_tags():
				if not tags.has(label.text):
					tags.append(label.text)
	)
	moments.on_event(event)
	var start: int = Time.get_ticks_msec()
	while moments.sequence.is_running() and Time.get_ticks_msec() - start < 8000:
		await await_idle_frame()
	(
		assert_array(tags)
		. is_equal(
			[
				"+10 " + tr("keyword.grain.name"),
				"+0.2 " + tr("keyword.zeal.name"),
				"+1 " + tr("score.step.coupon"),
			]
		)
	)
	assert_str(moments.tally.shown()).ends_with(Strings.score(event.amount))
