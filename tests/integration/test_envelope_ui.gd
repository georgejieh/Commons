extends GdUnitTestSuite
## Envelopes on screen (ADR 0021): each shop's offer is an envelope on the counter whose
## rules the shared slip shows; buying opens it over the page, which takes no purchase
## until it is answered; its papers are readable, focus lands on the first that can be
## kept, left and right move, a single cancel never throws it away; keeping updates the
## page, a Directive is issued with its seal; reduced motion skips the show; a load in
## mid-opening shows it open again; nothing is left behind; and the paper wears.

const SEED: int = 4242
const SAVE_PATH: String = "user://test_envelope_ui/run.json"
const WAIT_SECONDS: float = 5.0

var _app: DemoApp
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	get_tree().root.size = Vector2i(1920, 1080)
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)
	_app.new_run(SEED)
	var driver: ControllerScript = ControllerScript.new()
	while _app.controller.awaiting() != RunController.AWAIT_SET_OVER:
		driver.act(_app.controller)
	_app.controller.finish_set()
	_loop().state.coupons = 60
	_app.controller.reseal_book()


func after_test() -> void:
	get_tree().root.size = _was_size
	Settings.set_value("reduced_motion", false)
	ArtStages.stage_override = -1
	Saves.run_service().delete()


func _loop() -> RunLoop:
	return _app.controller.get("_loop")


func _open(screen_id: String = "store") -> StoreScreen:
	var store: StoreScreen = _app.show_screen(screen_id, true)
	await await_idle_frame()
	await await_idle_frame()
	return store


func _stall(store: StoreScreen) -> EnvelopeStall:
	return store.get("_envelope_stall")


## Puts one kind on the state store's counter, as only tests do.
func _offer(envelope_id: String) -> void:
	var stock: Array[String] = [envelope_id]
	_loop().shop.envelopes.set("_stock", stock)


func _wait(overlay: EnvelopeOverlay) -> void:
	var waited: float = 0.0
	while is_instance_valid(overlay) and overlay.is_busy() and waited < WAIT_SECONDS:
		await get_tree().process_frame
		waited += get_process_delta_time()


func _bought(store: StoreScreen) -> EnvelopeOverlay:
	_stall(store).panel(0).buy.pressed.emit()
	return _stall(store).overlay()


## No piece of the overlay is left, and the page holds as many nodes as a fresh redraw
## of it does.
func _check_nothing_left(store: StoreScreen) -> void:
	await await_idle_frame()
	await await_idle_frame()
	for kind: String in ["EnvelopeOverlay", "ChoicePaper", "EnvelopeFigure"]:
		var found: int = 0
		for node: Node in store.find_children("*", "", true, false):
			var script: Script = node.get_script()
			if script != null and script.get_global_name() == kind:
				found += 1
		assert_int(found).override_failure_message(kind).is_equal(0)
	var after: int = store.find_children("*", "", true, false).size()
	store.call("_refresh")
	await await_idle_frame()
	await await_idle_frame()
	assert_int(store.find_children("*", "", true, false).size()).is_equal(after)


func _cancel() -> void:
	var press: InputEventAction = InputEventAction.new()
	press.action = "ui_cancel"
	press.pressed = true
	get_viewport().push_input(press)
	var release: InputEventAction = InputEventAction.new()
	release.action = "ui_cancel"
	get_viewport().push_input(release)
	await await_idle_frame()


func test_each_shop_offers_an_envelope_explained_by_the_slip() -> void:
	for screen_id: String in ["store", "black_market"]:
		var store: StoreScreen = await _open(screen_id)
		var shelf: EnvelopeShelf = _app.controller.envelope_shelf(screen_id == "black_market")
		var offered: String = shelf.stock()[0]
		var panel: CounterPanel = _stall(store).panel(0)
		assert_int(panel.look()).is_equal(CounterPanel.Look.ENVELOPE)
		assert_int(panel.wrapping()).is_equal(shelf.wrapping(offered))
		assert_str(panel.shown_name()).is_equal(shelf.envelope_name(offered))
		assert_bool(panel.buy.disabled).is_false()
		panel.described.emit(panel)
		var slip: DetailSlip = store.slip()
		assert_bool(slip.visible).is_true()
		assert_str(slip.shown_rule()).is_equal(shelf.envelope_text(offered))
		assert_str(slip.shown_rule()).contains("3")
		assert_str(slip.shown_rule()).not_contains("{")
		assert_bool(slip.get_global_rect().intersects(panel.get_global_rect())).is_false()
	assert_int(_app.controller.envelope_shelf(true).wrapping("parcel")).is_equal(
		EnvelopeShelf.PARCEL
	)


func test_buying_opens_it_and_holds_every_other_purchase() -> void:
	var store: StoreScreen = await _open()
	var commands: int = _loop().record.commands.size()
	var overlay: EnvelopeOverlay = _bought(store)
	assert_object(overlay).is_not_null()
	assert_int(_loop().record.commands.size()).is_equal(commands + 1)
	assert_bool(overlay.is_busy()).is_true()
	assert_bool(store.is_issuing()).is_true()
	assert_bool(overlay.figure().visible).is_true()
	var cadres: int = _app.controller.state_copy().inventory.cadres.size()
	var counter: HBoxContainer = store.get("_counter")
	var cadre_buy: Button = counter.get_child(0).find_children("*", "Button", true, false)[0]
	cadre_buy.pressed.emit()
	var reroll: Button = store.get("_reroll")
	reroll.pressed.emit()
	var leave: Button = store.blocks()["buttons"].get_child(0)
	leave.pressed.emit()
	assert_int(_app.controller.state_copy().inventory.cadres.size()).is_equal(cadres)
	assert_int(_loop().record.commands.size()).is_equal(commands + 1)
	var switcher: SceneSwitcher = _app.get("switcher")
	assert_str(switcher.current_id()).is_equal("store")
	await _wait(overlay)
	assert_bool(overlay.is_busy()).is_false()
	assert_bool(overlay.figure().visible).is_false()
	var papers: Array[ChoicePaper] = overlay.papers()
	assert_int(papers.size()).is_equal(3)
	assert_bool(papers[0].keep.has_focus()).is_true()
	# Still held while the papers are at rest, until one is kept or none.
	reroll.pressed.emit()
	assert_int(_loop().record.commands.size()).is_equal(commands + 1)


func test_focus_moves_along_the_row_and_one_cancel_never_throws_it_away() -> void:
	Settings.set_value("reduced_motion", true)
	var store: StoreScreen = await _open()
	var overlay: EnvelopeOverlay = _bought(store)
	await await_idle_frame()
	var papers: Array[ChoicePaper] = overlay.papers()
	var keep: Button = papers[0].keep
	assert_bool(keep.has_focus()).is_true()
	assert_object(keep.get_node(keep.focus_neighbor_right)).is_same(papers[1].keep)
	assert_object(keep.get_node(keep.focus_neighbor_left)).is_same(keep)
	assert_object(keep.get_node(keep.focus_neighbor_bottom)).is_same(overlay.nothing_button())
	papers[1].keep.grab_focus()
	await await_idle_frame()
	assert_str(overlay.shown_title()).is_equal(papers[1].title)
	await _cancel()
	assert_bool(overlay.nothing_button().has_focus()).is_true()
	assert_bool(overlay.asks_to_confirm()).is_true()
	assert_object(_app.controller.opened_envelope()).is_not_null()
	assert_bool(_app.menu_is_open()).is_false()
	await _cancel()
	assert_object(_app.controller.opened_envelope()).is_null()
	assert_dict(_loop().record.commands[-1]).is_equal({"type": "envelope_pick", "index": -1})
	assert_bool(_stall(store).is_busy()).is_false()


## A choice that cannot be kept stays at full strength, its Keep off, with a refusal on
## a paper strip in dark red at a readable size; a reason every paper shares is said once,
## under the envelope's name (test_envelope_reads).
func test_a_choice_that_cannot_be_kept_says_why_at_full_strength() -> void:
	Settings.set_value("reduced_motion", true)
	_offer("campaign_envelope")
	_loop().state.inventory.consumables.assign(["grain_loan", "appeal"])
	var store: StoreScreen = await _open()
	var overlay: EnvelopeOverlay = _bought(store)
	await await_idle_frame()
	# With nothing to keep, the first paper is still explained and Take Nothing has focus.
	assert_str(overlay.shown_title()).is_equal(overlay.papers()[0].title)
	assert_str(overlay.shown_title()).is_not_empty()
	assert_bool(overlay.nothing_button().has_focus()).is_true()
	for paper: ChoicePaper in overlay.papers():
		assert_bool(paper.is_takeable()).is_false()
		assert_bool(paper.keep.disabled).is_true()
		assert_str(paper.caption()).is_equal(tr("envelope.refused.short"))
		assert_float(paper.modulate.a).is_equal(1.0)
		assert_float(paper.item.modulate.a).is_equal(1.0)
		assert_bool(paper.caption_strip().is_visible_in_tree()).is_true()
		var reason: Label = paper.caption_label()
		assert_int(reason.get_theme_font_size("font_size")).is_greater_equal(16)
		assert_object(reason.get_theme_color("font_color")).is_equal(ChoicePaper.REFUSED_INK)
	assert_bool(overlay.nothing_button().has_focus()).is_true()
	overlay.papers()[0].keep.pressed.emit()
	assert_object(_app.controller.opened_envelope()).is_not_null()
	overlay.nothing_button().pressed.emit()
	assert_object(_app.controller.opened_envelope()).is_null()
	assert_int(_app.controller.held_campaigns().size()).is_equal(2)


func test_keeping_a_directive_issues_it_under_its_seal() -> void:
	_offer("directive_envelope")
	var store: StoreScreen = await _open()
	var overlay: EnvelopeOverlay = _bought(store)
	await _wait(overlay)
	var paper: ChoicePaper = overlay.papers()[0]
	var directive_id: String = _app.controller.opened_envelope().item_id(0)
	var type: int = _app.controller.directive_types(directive_id)[0]
	var level: int = _app.controller.hand_level(type)
	assert_int(paper.lines.size()).is_equal(_app.controller.directive_types(directive_id).size())
	paper.keep.pressed.emit()
	assert_int(_app.controller.hand_level(type)).is_equal(level + 1)
	assert_bool(overlay.is_busy()).is_true()
	await get_tree().create_timer(0.4).timeout
	assert_str(overlay.seal().word()).is_equal(tr("directive.issued").to_upper())
	assert_bool(overlay.seal().visible).is_true()
	await _wait(overlay)
	await await_idle_frame()
	assert_bool(_stall(store).is_busy()).is_false()
	assert_bool(_stall(store).panel(0).buy.visible).is_false()


func test_a_kept_campaign_reaches_the_tray_and_nothing_is_left_behind() -> void:
	_offer("campaign_envelope")
	var store: StoreScreen = await _open()
	var overlay: EnvelopeOverlay = _bought(store)
	await _wait(overlay)
	var kept: String = _app.controller.opened_envelope().item_id(1)
	overlay.papers()[1].keep.pressed.emit()
	await get_tree().create_timer(0.3).timeout
	var word: String = overlay.seal().word()
	assert_str(word).is_equal(tr("envelope.kept").to_upper())
	await _wait(overlay)
	await await_idle_frame()
	await await_idle_frame()
	assert_bool(is_instance_valid(overlay)).is_false()
	assert_array(_app.controller.held_campaigns()).is_equal([kept])
	var stall: CampaignStall = store.get("_campaign_stall")
	var tray: CampaignTray = stall.tray
	assert_int(tray.campaign_count()).is_greater_equal(1)
	await _check_nothing_left(store)


func test_reduced_motion_opens_and_keeps_at_once() -> void:
	Settings.set_value("reduced_motion", true)
	var store: StoreScreen = await _open("black_market")
	var overlay: EnvelopeOverlay = _bought(store)
	assert_bool(overlay.is_busy()).is_false()
	assert_bool(overlay.figure().visible).is_false()
	var index: int = 0
	for paper: ChoicePaper in overlay.papers():
		if paper.is_takeable():
			index = paper.index
			break
	overlay.papers()[index].keep.pressed.emit()
	assert_object(_app.controller.opened_envelope()).is_null()
	assert_bool(_stall(store).is_busy()).is_false()
	await _check_nothing_left(store)


## The Parcel's plot cards show their marks plainly, with a caption saying what each does.
func test_parcel_cards_show_their_marks() -> void:
	Settings.set_value("reduced_motion", true)
	var seen: int = 0
	for attempt: int in 12:
		var store: StoreScreen = await _open("black_market")
		var overlay: EnvelopeOverlay = _bought(store)
		if overlay == null:
			break
		var shelf: EnvelopeShelf = _app.controller.opened_envelope()
		for paper: ChoicePaper in overlay.papers():
			var kind: int = shelf.kind(paper.index)
			if kind == EnvelopeShelf.KIND_STAMPED or kind == EnvelopeShelf.KIND_MODEL:
				var view: CardView = paper.item as CardView
				assert_object(view).is_not_null()
				assert_bool(view.shows_stamp()).is_equal(kind == EnvelopeShelf.KIND_STAMPED)
				var model: bool = view.shown_enhancement() == CardInstance.MODEL
				assert_bool(model).is_equal(kind == EnvelopeShelf.KIND_MODEL)
				assert_str(paper.caption()).is_not_empty()
				assert_str(paper.caption()).not_contains("{")
				seen += 1
		overlay.nothing_button().pressed.emit()
		if seen > 0:
			break
		# Another visit for another Parcel.
		_app.controller.leave_store()
		var driver: ControllerScript = ControllerScript.new()
		while _app.controller.awaiting() != RunController.AWAIT_SET_OVER:
			driver.act(_app.controller)
		_app.controller.finish_set()
		_loop().state.coupons = 60
		_app.controller.reseal_book()
	assert_int(seen).is_greater(0)


## A save taken while choosing loads back into the same envelope, open on the page.
func test_a_load_mid_opening_shows_the_envelope_open() -> void:
	Settings.set_value("reduced_motion", true)
	var store: StoreScreen = await _open()
	var overlay: EnvelopeOverlay = _bought(store)
	var titles: Array[String] = []
	for paper: ChoicePaper in overlay.papers():
		titles.append(paper.title)
	_app.resume_to_screen()
	await await_idle_frame()
	await await_idle_frame()
	var switcher: SceneSwitcher = _app.get("switcher")
	var again: StoreScreen = switcher.current() as StoreScreen
	assert_object(again).is_not_null()
	var reopened: EnvelopeOverlay = _stall(again).overlay()
	assert_object(reopened).is_not_null()
	var shown: Array[String] = []
	for paper: ChoicePaper in reopened.papers():
		shown.append(paper.title)
	assert_array(shown).is_equal(titles)


## Nothing drawn is clean: envelope paper is aged at stage 0 and more so at the last.
func test_envelope_paper_is_aged_and_wears_with_the_stage() -> void:
	ArtStages.stage_override = 0
	for wrapping: int in [EnvelopeShelf.STRING_TIE, EnvelopeShelf.WAX_SEAL, EnvelopeShelf.PARCEL]:
		var fresh: Color = EnvelopePaper.paper(wrapping, BowlGrime.wear())
		assert_bool(fresh.is_equal_approx(Color.WHITE)).is_false()
		ArtStages.stage_override = BoardState.CORRUPTION_STAGES - 1
		var worn: Color = EnvelopePaper.paper(wrapping, BowlGrime.wear())
		assert_float(worn.get_luminance()).is_less(fresh.get_luminance())
		ArtStages.stage_override = 0
	# The two state store envelopes tell apart at a glance: different paper and closure.
	var tie: Color = EnvelopePaper.paper(EnvelopeShelf.STRING_TIE, 0.3)
	var seal: Color = EnvelopePaper.paper(EnvelopeShelf.WAX_SEAL, 0.3)
	assert_float(absf(tie.get_luminance() - seal.get_luminance())).is_greater(0.1)


## A paper is its own button: it shows no Keep button, a click on the item keeps it, and
## the pointed paper is the one lit, with a Keep tag, while the others are not. An
## envelope of Directives has no explanation under the row, since each document says
## everything itself; an envelope of Campaigns has one.
func test_a_paper_is_kept_by_clicking_it_and_only_the_pointed_one_is_lit() -> void:
	Settings.set_value("reduced_motion", true)
	_offer("directive_envelope")
	var store: StoreScreen = await _open()
	var overlay: EnvelopeOverlay = _bought(store)
	await await_idle_frame()
	await await_idle_frame()
	var papers: Array[ChoicePaper] = overlay.papers()
	assert_bool(overlay.blocks().has("detail")).is_false()
	for paper: ChoicePaper in papers:
		assert_str(paper.keep.text).is_empty()
		var item: Rect2 = EnvelopeOverlay.shown_rect(paper.item)
		assert_bool(paper.keep.get_global_rect().grow(1.5).encloses(item)).is_true()
		assert_bool(paper.is_pointed()).is_equal(paper.index == 0)
		assert_bool(paper.shows_keep_tag()).is_equal(paper.index == 0)
	papers[2].keep.mouse_entered.emit()
	assert_bool(papers[2].is_pointed() and papers[2].shows_keep_tag()).is_true()
	assert_bool(papers[0].is_pointed() or papers[0].shows_keep_tag()).is_false()
	assert_str(overlay.shown_title()).is_equal(papers[2].title)
	papers[2].keep.pressed.emit()
	assert_object(_app.controller.opened_envelope()).is_null()
	assert_dict(_loop().record.commands[-1]).is_equal({"type": "envelope_pick", "index": 2})
	_offer("campaign_envelope")
	_loop().state.coupons = 60
	_app.controller.reseal_book()
	store = await _open()
	overlay = _bought(store)
	await await_idle_frame()
	assert_bool(overlay.blocks().has("detail")).is_true()
	overlay.nothing_button().pressed.emit()
