extends GdUnitTestSuite
## ADR 0021's Cadres on screen: the rank picker in the black market, counts on the
## notice board, The Bookkeeper in the Quota report, and the collection's sections, the
## Cadres of both shops first, that scroll with focus.

const SEED: int = 4301
const SAVE_PATH: String = "user://test_cadre_ui/run.json"

var _app: DemoApp


func before_test() -> void:
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)
	_app.new_run(SEED)
	var controller: RunController = _app.controller
	var driver: ControllerScript = ControllerScript.new()
	while driver.act(controller):
		pass


func after_test() -> void:
	Saves.run_service().delete()


func _loop() -> RunLoop:
	return _app.controller.run_loop()


## Opens the black market with Rehabilitation on its first slot. The stock is set behind
## the controller, so this visit is never replayed.
func _market_with_rehabilitation() -> StoreScreen:
	_app.controller.finish_set()
	var loop: RunLoop = _loop()
	loop.state.coupons = 100
	_app.controller.reseal_book()
	var stock: Array[String] = ["rehabilitation", "show_trial", "last_sheaf"]
	loop.visit.market.set("_stock", stock)
	return _app.show_screen("black_market")


func _buy_button(store: StoreScreen, slot: int) -> Button:
	var counter: HBoxContainer = store.get("_counter")
	return counter.get_child(slot).find_children("*", "Button", true, false)[0]


func test_buying_a_rank_cadre_asks_for_a_rank_then_seals_it_with_the_rank() -> void:
	var store: StoreScreen = _market_with_rehabilitation()
	await await_idle_frame()
	_buy_button(store, 0).pressed.emit()
	var picker: RankPicker = store.get("_picker")
	assert_bool(picker.is_open()).is_true()
	assert_array(_app.controller.state_copy().inventory.cadres).not_contains(["rehabilitation"])
	var chips: Array[RankChip] = picker.chips()
	assert_int(chips.size()).is_equal(13)
	assert_int(chips[0].rank).is_equal(Ranks.THREE)
	assert_int(chips[-1].rank).is_equal(Ranks.TWO)
	await await_idle_frame()
	# Focus lands on the first ticket and walks along the strip and down to Cancel.
	assert_object(get_viewport().gui_get_focus_owner()).is_same(chips[0])
	assert_object(chips[0].find_valid_focus_neighbor(SIDE_RIGHT)).is_same(chips[1])
	var cancel: Button = picker.get("_cancel")
	assert_object(chips[5].find_valid_focus_neighbor(SIDE_BOTTOM)).is_same(cancel)
	chips[Ranks.SEVEN].pressed.emit()
	assert_bool(picker.is_open()).is_false()
	var state: RunState = _app.controller.state_copy()
	assert_array(state.inventory.cadres).contains(["rehabilitation"])
	assert_int(state.cadre_memos.peek("rehabilitation").value(CadreMemo.RANK)).is_equal(Ranks.SEVEN)
	# The normal purchase follows: sealed, then pinned.
	assert_bool(store.is_buying()).is_true()
	var seal: InkSeal = store.get("_seal")
	assert_bool(seal.visible).is_true()
	await await_millis(int((StoreScreen.SEAL_HOLD + StoreScreen.PIN_TIME) * 1000.0) + 300)
	var board: NoticeBoard = store.get("_board")
	var slot: int = state.inventory.cadres.find("rehabilitation")
	assert_str(board.count_at(slot)).is_equal("7s")
	var cards: Array[TipHost] = board.get("_cards")
	assert_str(cards[slot].tip_rule()).contains("Your 7s")


func test_cancel_closes_the_picker_with_nothing_bought() -> void:
	var store: StoreScreen = _market_with_rehabilitation()
	await await_idle_frame()
	var coupons: int = _app.controller.state_copy().coupons
	_buy_button(store, 0).pressed.emit()
	var picker: RankPicker = store.get("_picker")
	var cancel: Button = picker.get("_cancel")
	cancel.pressed.emit()
	assert_bool(picker.is_open()).is_false()
	assert_int(_app.controller.state_copy().coupons).is_equal(coupons)
	assert_bool(store.is_issuing()).is_false()
	# A Cadre with no rank to pick buys at once.
	_buy_button(store, 1).pressed.emit()
	assert_bool(picker.is_open()).is_false()
	assert_array(_app.controller.state_copy().inventory.cadres).contains(["show_trial"])


func test_a_cadre_with_a_count_shows_it_on_its_card_and_swells_when_it_fires() -> void:
	var loop: RunLoop = _loop()
	loop.state.inventory.cadres.assign(["seed_grain", "the_bookkeeper"])
	loop.state.cadre_memos.entry("seed_grain").put(SeedGrainEffect.MET, 2)
	var board: NoticeBoard = auto_free(NoticeBoard.new())
	add_child(board)
	board.setup(3)
	board.show_cadres(_app.controller)
	assert_str(board.count_at(0)).is_equal("+6")
	assert_str(board.count_at(1)).is_empty()
	var cards: Array[TipHost] = board.get("_cards")
	assert_str(cards[0].tip_rule()).contains("Now +6 Grain on each of your plays.")
	board.fired(_app.controller, "the_bookkeeper", 2)
	assert_str(board.count_at(1)).is_equal("+2")
	# Drawn on the card, never a label over the table.
	assert_int(board.find_children("*", "Label", true, false).size()).is_equal(0)


func test_the_quota_report_counts_the_bookkeepers_coupons_in_the_paid_line() -> void:
	var loop: RunLoop = _loop()
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.SET_OVER)
	loop.set_log.add(RunEvent.new(RunEvent.Type.CADRE_FIRED, 0, 2, 0.0, "the_bookkeeper"))
	loop.state.coupons += 2
	_app.controller.reseal_book()
	var report: SetSummaryScreen = _app.show_screen("set_summary", true)
	await await_idle_frame()
	var after: Array[Control] = report.get("_after")
	var met: bool = report.get("_met")
	var name: String = tr("modifier.the_bookkeeper.name")
	if met:
		var paid: int = (
			_app.controller.figures.quota_reward() + _app.controller.figures.over_bonus() + 2
		)
		var line: Label = after[1]
		var words: Dictionary = {"count": paid, "kept": 2, "cadre": name}
		assert_str(line.text).is_equal(tr("summary.paid_with").format(words))
	else:
		var kept: Label = after[2]
		var text: String = Strings.count("summary.cadre_paid", 2).format({"cadre": name})
		assert_str(kept.text).is_equal(text)


func test_the_collections_sections_scroll_with_focus() -> void:
	var collection: CollectionScreen = _app.show_screen("collection")
	await await_idle_frame()
	var flows: Array[Node] = collection.find_children("*", "HFlowContainer", true, false)
	assert_int(flows.size()).is_equal(CollectionView.SECTION_KEYS.size())
	assert_int(flows[0].get_child_count()).is_equal(RunPools.STORE_CADRES.cadres.size())
	assert_int(flows[1].get_child_count()).is_equal(RunPools.MARKET_CADRES.cadres.size())
	var entries: Array[Control] = collection.entries()
	assert_int(entries.size()).is_equal(CollectionView.for_runs(0).total())
	for entry: Control in entries:
		assert_int(entry.focus_mode).is_equal(Control.FOCUS_ALL)
	assert_bool(collection.scroll().follow_focus).is_true()
	entries[0].grab_focus()
	assert_object(entries[0].find_valid_focus_neighbor(SIDE_RIGHT)).is_same(entries[1])
	entries[-1].grab_focus()
	await await_idle_frame()
	await await_idle_frame()
	assert_int(collection.scroll().scroll_vertical).is_greater(0)
