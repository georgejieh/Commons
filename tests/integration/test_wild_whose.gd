extends GdUnitTestSuite
## Whose wild ranks the table shows (ADR 0039, second note of 2026-11-24). Every item that
## makes a rank wild is the player's, so the ranks are the player's alone: the call-out and
## the rules strip say so, a villager's played card of the rank lands on the pile plain,
## with no ribbon and no stand-in label, the player's own lands with its ribbon, and a
## Reform's rule that changes play is listed as the player's, never as the whole table's.

const SEED: int = 4242
const WAIT_SECONDS: float = 12.0
const SCREEN: Vector2i = Vector2i(1920, 1080)
const WORKER: Array[String] = ["model_worker"]

var _app: DemoApp
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	get_tree().root.size = SCREEN
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)


func after_test() -> void:
	get_tree().root.size = _was_size
	Saves.run_service().delete()


func _loop() -> RunLoop:
	return _app.controller.run_loop()


## A new run with the player holding Model Worker, played to the player's first lead.
func _to_first_lead() -> bool:
	_app.new_run(SEED)
	_loop().state.inventory.consumables.assign(WORKER)
	var driver: ControllerScript = ControllerScript.new()
	for _step: int in 900:
		var awaiting: int = _app.controller.awaiting()
		var view: SeatView = _app.controller.table.seat_view()
		if awaiting == RunController.AWAIT_PLAY and view.public.history.is_empty():
			return true
		if awaiting == RunController.AWAIT_SET_OVER:
			_app.controller.finish_set()
		elif awaiting == RunController.AWAIT_STORE:
			_loop().state.inventory.consumables.assign(WORKER)
			_app.controller.leave_store()
		elif not driver.act(_app.controller):
			return false
	return false


func _wait_idle(table: TableScreen) -> void:
	var player: EventPlayer = table.player
	await TestWait.until(
		self, func() -> bool: return player.is_idle(), "the table's events to play", WAIT_SECONDS
	)


## Two cards of the rank, as a seat's play of them reads under that seat's rules.
func _pair_event(seat: int, rank: int) -> RoundEvent:
	var cards: Array[CardInstance] = [
		Deck.new().card(rank * Deck.SUITS), Deck.new().card(rank * Deck.SUITS + 1)
	]
	var table: BotTable = _loop().seat_table(seat)
	var counts: PackedByteArray = CardSelection.printed_counts(cards)
	var reading: Pattern = Classifier.classify(counts, table.rules, table.standing).pattern
	var ids: Array[int] = [cards[0].id(), cards[1].id()]
	var event: RoundEvent = RoundEvent.new(RoundEvent.Type.PLAYED, seat, ids, reading)
	event.cards.assign(cards)
	return event


func test_the_words_and_the_pile_say_the_wild_rank_is_the_players() -> void:
	assert_bool(_to_first_lead()).is_true()
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	await await_idle_frame()
	var strip: DebuffStrip = table.debuffs
	var moments: TableMoments = table.moments
	assert_int(_app.controller.campaign(0)).is_equal(RunController.OK)
	var rank: int = _app.controller.table.wild_ranks()[0]
	await TestWait.until(
		self, func() -> bool: return moments.callout.is_showing(), "the callout", WAIT_SECONDS
	)
	assert_str(moments.callout.shown_sub()).is_equal(tr("callout.wild.sub"))
	await _wait_idle(table)
	assert_str(strip.shown_text()).contains(tr("wild.strip"))
	for key: String in ["wild.strip", "callout.wild.sub", "callout.wild.sub.two"]:
		assert_str(tr(key)).not_contains("every seat")
	# The rules say so: the player's seat holds the rank wild, a villager's does not.
	assert_array(_loop().seat_table(0).rules.wild_ranks()).is_equal([rank])
	assert_array(_loop().seat_table(1).rules.wild_ranks()).is_empty()
	var pile: TrickPile = table.pile
	var motion: TableMotion = table.motion
	motion.set_still(true)
	table.player.push(RunEvent.wrap(_pair_event(1, rank)))
	table.player.flush()
	for view: CardView in pile.top_views():
		assert_bool(view.shows_wild()).override_failure_message("villager's card").is_false()
		assert_str(view.rank_note()).is_empty()
	table.player.push(RunEvent.wrap(_pair_event(0, rank)))
	table.player.flush()
	for view: CardView in pile.top_views():
		assert_bool(view.shows_wild()).override_failure_message("player's card").is_true()
	pile.clear()
	motion.set_still(false)


## Industrialization is the player's rule: the strip lists it under the player's Reforms.
func test_a_reforms_rule_is_listed_as_the_players() -> void:
	assert_bool(_to_first_lead()).is_true()
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	_loop().state.reforms.assign(["industrialization"])
	_loop().call("_rebuild_modifiers")
	var strip: DebuffStrip = table.debuffs
	strip.show_debuffs(_app.controller)
	var shown: String = strip.shown_text()
	assert_str(shown).contains(tr("table.rules_reforms").to_upper())
	assert_str(shown).contains(tr("reform.industrialization.name"))
	assert_bool(_loop().seat_table(0).rules.five_plus_is_bomb()).is_true()
	assert_bool(_loop().seat_table(1).rules.five_plus_is_bomb()).is_false()
	for key: String in ["reform.industrialization.text", "reform.mass_line.text"]:
		assert_str(tr(key)).not_contains("every seat")
	assert_str(tr("campaign.model_worker.text")).not_contains("every seat")
