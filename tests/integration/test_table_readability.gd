extends GdUnitTestSuite
## What the table makes plain at a glance: the trick pile shows the play to beat on top,
## upright with every rank in view; one villager talks at a time; court cards and
## jokers read as picture cards; and a debuff that re-ranks cards is in view on the
## table and on the cards it changes.

## A seed whose first Set reaches Criticism Meeting (2s rank as 3s) in round 3.
const SEED: int = 3
const RANK_DEBUFF: String = "criticism_meeting"
const SAVE_PATH: String = "user://test_table_readability/run.json"
const CARD_SCENE: PackedScene = preload("res://ui/cards/card_view.tscn")
## How much of each card in a play must show: enough for its rank and suit.
const SHOWN_WIDTH: float = 40.0

var _app: DemoApp


func before_test() -> void:
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)
	_app.new_run(SEED)


func after_test() -> void:
	Saves.run_service().delete()


func test_the_newest_play_lies_on_top_upright_with_every_rank_showing() -> void:
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	var pile: TrickPile = table.get("_pile")
	pile.show_play(_cards([0, 1]), Vector2.ZERO)
	pile.show_play(_cards([10, 11, 12, 13, 14]), Vector2.ZERO)
	await await_millis(int((TableMotion.PRESETS.fly_time + 0.4) * 1000.0))
	assert_int(pile.play_count()).is_equal(2)
	assert_array(pile.top_ids()).is_equal([10, 11, 12, 13, 14])
	var top: Array[CardView] = pile.top_views()
	var tilt: float = TrickPile.PLAY_TILT + TrickPile.CARD_TILT
	for index: int in top.size():
		var view: CardView = top[index]
		assert_float(absf(view.rotation)).is_less_equal(tilt)
		assert_float(view.modulate.v).is_equal_approx(1.0, 0.001)
		if index > 0:
			var step: float = view.position.x - top[index - 1].position.x
			assert_float(step).is_greater_equal(SHOWN_WIDTH)
	for child: Node in pile.get_children():
		var buried: CardView = child as CardView
		if buried != null and not top.has(buried):
			assert_float(buried.modulate.v).is_less(0.9)


func test_every_card_of_a_fresh_deal_shows_its_face() -> void:
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	var hand_view: HandView = table.get("_hand_view")
	hand_view.show_cards()
	hand_view.deal_in()
	var settle: float = TableMotion.PRESETS.fly_time + 20 * TableMotion.PRESETS.deal_stagger
	await await_millis(int((settle + 0.4) * 1000.0))
	var shown: int = 0
	for child: Node in hand_view.get_children():
		var view: CardView = child as CardView
		if view == null or not view.visible:
			continue
		shown += 1
		var rank: Label = view.get_node("Frame/Rank")
		assert_str(rank.text).is_not_empty()
		assert_float(view.modulate.a).is_equal_approx(1.0, 0.001)
		assert_float(rank.get_global_rect().size.x).is_greater(0.0)
	assert_int(shown).is_equal(_app.hand.cards().size())


func test_the_same_play_lands_the_same_way() -> void:
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	var pile: TrickPile = table.get("_pile")
	Settings.set_value("reduced_motion", true)
	var motion: TableMotion = table.get("_motion")
	motion.set_reduced(true)
	pile.show_play(_cards([5, 6, 7]), Vector2.ZERO)
	var first: Array[Vector2] = _spots(pile.top_views())
	pile.clear()
	pile.show_play(_cards([5, 6, 7]), Vector2.ZERO)
	assert_array(_spots(pile.top_views())).is_equal(first)
	Settings.set_value("reduced_motion", false)


func test_a_second_villager_waits_until_the_first_finishes() -> void:
	var first: SeatPanel = auto_free(SeatPanel.new())
	var second: SeatPanel = auto_free(SeatPanel.new())
	add_child(first)
	add_child(second)
	first.seat = 1
	second.seat = 2
	var speech: TableSpeech = TableSpeech.new()
	var seats: Dictionary[int, SeatPanel] = {1: first, 2: second}
	speech.setup(seats)
	first.say("You going to play that?", "", PackedFloat32Array([0.1, 0.2, 0.3]))
	speech.say(2, "pass")
	assert_int(speech.waiting_count()).is_equal(1)
	assert_str(second.speech()).is_empty()
	first._process(1.0)
	assert_bool(first.is_typing()).is_false()
	assert_int(speech.waiting_count()).is_equal(0)
	assert_str(second.speech()).is_not_empty()


func test_a_villagers_line_goes_when_they_act_again() -> void:
	var first: SeatPanel = auto_free(SeatPanel.new())
	var second: SeatPanel = auto_free(SeatPanel.new())
	add_child(first)
	add_child(second)
	first.seat = 1
	second.seat = 2
	var speech: TableSpeech = TableSpeech.new()
	var seats: Dictionary[int, SeatPanel] = {1: first, 2: second}
	speech.setup(seats)
	speech.say(1, "bomb")
	speech.say(2, "won")
	assert_str(first.speech()).is_not_empty()
	var single: Pattern = Pattern.new(
		Pattern.Type.SINGLE, Ranks.FIVE, 1, 1, PackedByteArray(), Ranks.FIVE
	)
	var ids: Array[int] = [0]
	speech.on_event(RunEvent.wrap(RoundEvent.new(RoundEvent.Type.PLAYED, 1, ids, single)))
	assert_str(first.speech()).is_empty()
	assert_str(second.speech()).is_not_empty()


func test_the_need_panel_says_what_a_declaration_pays() -> void:
	var panel: NeedPanel = auto_free(NeedPanel.new())
	add_child(panel)
	panel.setup(10, 40, 5)
	panel.ask(1200, "Zhao", 0.15)
	assert_int(panel.percent()).is_equal(50)
	assert_int(panel.preview_share()).is_equal(600)
	var shown: Label = panel.get("_value")
	assert_str(shown.text).is_equal("50%")
	var more: Button = panel.get("_more")
	for _step: int in 10:
		more.pressed.emit()
	assert_int(panel.value()).is_equal(20)
	assert_int(panel.percent()).is_equal(67)
	assert_int(panel.preview_share()).is_equal(800)
	var note: Label = panel.get("_note")
	assert_str(note.text).is_equal(tr("need.lie").format({"rise": 5, "chance": 15}))


func test_the_need_panel_stays_on_screen_and_centered() -> void:
	var panel: NeedPanel = auto_free(NeedPanel.new())
	add_child(panel)
	panel.center = Vector2(790, 520)
	panel.setup(10, 40, 5)
	panel.ask(1900, "Zhao", 0.15)
	await await_millis(200)
	assert_float(panel.position.y + panel.size.y).is_less(760.0)
	assert_float(panel.position.x + panel.size.x / 2.0).is_equal_approx(790.0, 1.0)
	var declare: Button = panel.get("_declare")
	assert_float(declare.size.x).is_less(panel.size.x * 0.7)


func test_every_bid_is_stamped_and_stays_on_its_seat() -> void:
	var fx: TableFx = auto_free(TableFx.new())
	var slip: AuditSlip = auto_free(AuditSlip.new())
	var ledger: Ledger = auto_free(Ledger.new())
	var wang: SeatPanel = auto_free(SeatPanel.new())
	var zhao: SeatPanel = auto_free(SeatPanel.new())
	for node: Node in [fx, slip, ledger, wang, zhao]:
		add_child(node)
	var seats: Dictionary[int, SeatPanel] = {1: wang, 2: zhao}
	var moments: TableMoments = TableMoments.new()
	var spot: Callable = func(_seat: int) -> Vector2: return Vector2(400, 300)
	moments.setup(fx, slip, ledger, seats, spot, func() -> Vector2: return Vector2(700, 500))
	moments.on_event(RunEvent.new(RunEvent.Type.BID, 1, 1))
	moments.on_event(RunEvent.new(RunEvent.Type.BID, 2, 1))
	moments.on_event(RunEvent.new(RunEvent.Type.BID, 0, 0))
	moments.on_event(RunEvent.new(RunEvent.Type.BID, 1, 1))
	assert_str(moments.bid_key(1)).is_equal("bid.grab")
	assert_str(moments.bid_key(2)).is_equal("bid.grab")
	assert_str(moments.bid_key(0)).is_equal("bid.pass")
	var role: Label = wang.get("_role")
	assert_str(role.text).is_equal(tr("bid.grab").to_upper())
	var words: PackedStringArray = fx.stamped()
	assert_array(Array(words)).contains(
		[tr("stamp.call").to_upper(), tr("stamp.grab").to_upper(), tr("stamp.no_call").to_upper()]
	)
	moments.on_event(RunEvent.new(RunEvent.Type.LANDLORD_CHOSEN, 1, 0))
	assert_str(moments.bid_key(1)).is_empty()


func test_the_audit_slip_shows_each_claim_its_verdict_and_its_pay() -> void:
	var slip: AuditSlip = auto_free(AuditSlip.new())
	add_child(slip)
	var names: Dictionary[int, String] = {0: "You", 2: "Zhao"}
	slip.setup(names)
	slip.claim(0, 20)
	slip.claim(2, 10)
	assert_bool(slip.visible).is_true()
	assert_str(slip.row_text(0)).contains(tr("audit.claim").format({"name": "You", "percent": 67}))
	assert_str(slip.row_text(2)).contains(tr("audit.rolling"))
	slip.audited(0, true)
	slip.paid(0, 600)
	slip.paid(2, 600)
	assert_str(slip.row_text(0)).contains(tr("audit.caught"))
	assert_str(slip.row_text(0)).contains(tr("audit.paid").format({"amount": Strings.score(600)}))
	assert_str(slip.row_text(2)).contains(tr("audit.clear"))
	slip.clear()
	assert_bool(slip.visible).is_false()


func test_a_rule_for_the_whole_table_says_so() -> void:
	assert_bool(_app.controller.is_table_wide("promotion_of_the_masses")).is_true()
	assert_bool(_app.controller.is_table_wide(RANK_DEBUFF)).is_false()
	var rule: String = ScreenKit.rule_text(_app.controller, "promotion_of_the_masses")
	assert_str(rule).contains(tr("modifier.table_wide"))
	assert_str(ScreenKit.rule_text(_app.controller, RANK_DEBUFF)).not_contains(
		tr("modifier.table_wide")
	)


func test_keywords_explain_themselves() -> void:
	var marked: String = Keywords.mark("Your plays gain 5 Grain and lose 1 Zeal.")
	assert_str(marked).contains('[hint="Grain:')
	assert_str(marked).contains('[hint="Zeal:')
	var zeal: String = Keywords.wrapped(tr("keyword.zeal.text"))
	assert_str(Keywords.tip("Your plays lose 1 Zeal.")).is_equal(zeal)
	assert_str(Keywords.tip("Pass.")).is_empty()
	# A keyword reads as a link, in any case and in the plural, as it was written.
	var kickers: String = Keywords.mark("Your kickers score.")
	assert_str(kickers).contains('[hint="Kicker:')
	assert_str(kickers).contains("[u]kickers[/u]")
	assert_array(Array(Keywords.found("While you are landlord, kitty cards count."))).is_equal(
		["landlord", "kitty"]
	)
	for line: String in Keywords.wrapped(tr("keyword.audit.text")).split("\n"):
		assert_int(line.length()).is_less_equal(Keywords.WRAP_COLUMNS)
	# Every keyword has a name and a meaning in the string table.
	for id: String in Keywords.TERMS:
		assert_str(tr("keyword.%s.name" % id)).is_not_equal("keyword.%s.name" % id)
		assert_str(Keywords.meaning(id)).is_not_equal("keyword.%s.text" % id)
	# Every keyword's markup parses: nothing of the tags is left in the shown text.
	var shown: RichTextLabel = auto_free(RichTextLabel.new())
	shown.bbcode_enabled = true
	add_child(shown)
	var plain: String = "Grain × Zeal goes to the Commons; Bombs and kickers, the kitty, an Audit."
	shown.text = Keywords.mark(plain)
	assert_str(shown.get_parsed_text()).is_equal(plain)


func test_court_cards_and_jokers_are_picture_cards() -> void:
	var view: CardView = auto_free(CARD_SCENE.instantiate())
	add_child(view)
	for rank: int in Ranks.COUNT:
		var card: CardInstance = CardInstance.from_deck_id(_deck_id(rank))
		view.bind(card)
		var picture: bool = rank >= Ranks.JACK and rank <= Ranks.KING
		picture = picture or rank >= Ranks.SMALL_JOKER
		assert_bool(view.is_picture_card()).override_failure_message(str(rank)).is_equal(picture)
		var art: TextureRect = view.get_node("Frame/Picture")
		if picture:
			assert_float(art.size.x).is_greater(view.size.x * 0.85)
		else:
			assert_float(art.size.x).is_less(view.size.x * 0.6)


func test_a_fold_names_the_rank_a_card_counts_as() -> void:
	var folded: PackedByteArray = Ranks.identity_map()
	folded[Ranks.TWO] = folded[Ranks.THREE]
	assert_int(HandModel.fold(Ranks.TWO, folded)).is_equal(Ranks.THREE)
	assert_int(HandModel.fold(Ranks.THREE, folded)).is_equal(-1)
	assert_int(HandModel.fold(Ranks.ACE, folded)).is_equal(-1)
	var inverted: PackedByteArray = PackedByteArray()
	for rank: int in Ranks.COUNT:
		inverted.append(Ranks.COUNT - 1 - rank)
	for rank: int in Ranks.COUNT:
		assert_int(HandModel.fold(rank, inverted)).is_equal(-1)


func test_a_rank_debuff_shows_on_the_table_and_on_the_cards_it_changes() -> void:
	assert_array(_app.controller.ladder()).contains([RANK_DEBUFF])
	_app.show_screen("table", true)
	await await_idle_frame()
	var driver: ControllerScript = ControllerScript.new()
	var saw_note: bool = false
	var saw_strip: bool = false
	for _turn: int in 800:
		if _app.switcher.current_id() != "table" or (saw_note and saw_strip):
			break
		# The table is built afresh for each round, so look it up every turn.
		var table: TableScreen = _app.switcher.current()
		table.skip_events()
		await await_idle_frame()
		if _app.switcher.current() != table:
			continue
		var strip: DebuffStrip = table.get("_debuffs")
		var hand_view: HandView = table.get("_hand_view")
		var active: bool = _app.controller.active_debuff_ids().has(RANK_DEBUFF)
		var name: String = tr("modifier.%s.name" % RANK_DEBUFF)
		assert_bool(strip.shown_text().contains(name)).is_equal(active)
		saw_strip = saw_strip or active
		saw_note = saw_note or (active and _twos_marked(hand_view))
		_press(table, driver)
	assert_bool(saw_strip).is_true()
	assert_bool(saw_note).is_true()


## The cheat sheet test's moves, which reach round 3 on this seed: decline every bid.
func _press(table: TableScreen, driver: ControllerScript) -> void:
	match _app.controller.awaiting():
		RunController.AWAIT_BID:
			table.actions().decline.pressed.emit()
		RunController.AWAIT_NEED:
			table.need_panel().declared.emit(ControllerScript.NEED)
		RunController.AWAIT_PLAY:
			var ids: Array[int] = driver.choose_play(_app.controller)
			if ids.is_empty():
				table.actions().pass_turn.pressed.emit()
				return
			for card_id: int in ids:
				_app.hand.toggle(card_id)
			table.actions().play.pressed.emit()


## True when the fan holds a 2 and every 2 in it says it ranks as a 3.
func _twos_marked(hand_view: HandView) -> bool:
	var note: String = tr("card.rank_as").format({"rank": tr(CardView.RANK_KEYS[Ranks.THREE])})
	var ranks: Dictionary[int, int] = {}
	for card: CardInstance in _app.hand.cards():
		ranks[card.id()] = card.base_rank()
	var twos: int = 0
	for child: Node in hand_view.get_children():
		var view: CardView = child as CardView
		if view == null or not view.visible or ranks.get(view.card_id, -1) != Ranks.TWO:
			continue
		twos += 1
		if view.rank_note() != note:
			return false
		# A 2 that ranks as a 3 is sorted with the 3s: only 3s and 2s sit to its left.
		for other: Node in hand_view.get_children():
			var left: CardView = other as CardView
			if left == null or not left.visible or left.get_index() >= view.get_index():
				continue
			var rank: int = ranks.get(left.card_id, -1)
			if rank != Ranks.THREE and rank != Ranks.TWO:
				return false
	return twos > 0


func _cards(deck_ids: Array[int]) -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for deck_id: int in deck_ids:
		cards.append(CardInstance.from_deck_id(deck_id))
	return cards


func _spots(views: Array[CardView]) -> Array[Vector2]:
	var spots: Array[Vector2] = []
	for view: CardView in views:
		spots.append(Vector2(view.position.x, view.rotation))
	return spots


## The first deck ID with this rank.
func _deck_id(rank: int) -> int:
	for deck_id: int in 54:
		if CardInstance.from_deck_id(deck_id).base_rank() == rank:
			return deck_id
	return -1
