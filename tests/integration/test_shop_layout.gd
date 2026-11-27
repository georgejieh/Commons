extends GdUnitTestSuite
## Both shops fit the screen (ADR 0021): at 1920x1080 and at the Steam Deck's 1280x800,
## every visible control lies inside the screen and no two of the page's main blocks
## overlap, both with a fresh run and with the most a run can hold: six Cadres, three
## Campaigns, all six Reforms in force, rationing's note, the two tallest Directives and a
## set black market counter.

const SEED: int = 4242
const SIX: Array[String] = [
	"iron_rice_bowl", "canteen", "red_banner", "peek", "stakhanovite", "red_ink"
]
const ALL_REFORMS: Array[String] = [
	"supply_cooperative",
	"work_point_reform",
	"enlarged_committee",
	"grain_reserve",
	"couriers_bag",
	"unplanned_economy",
]

var _app: App
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)
	_app.new_run(SEED)
	var driver: ControllerScript = ControllerScript.new()
	driver.play_to(self, _app.controller, RunController.AWAIT_SET_OVER)
	_app.controller.finish_set()


func after_test() -> void:
	Settings.set_value(TextSize.SETTING, 0)
	get_tree().root.size = _was_size
	Saves.run_service().delete()


func _loop() -> RunLoop:
	return _app.controller.run_loop()


## Hands the run the most it can hold, behind the controller, as only tests do.
func _fill() -> void:
	var state: RunState = _loop().state
	state.reforms.assign(ALL_REFORMS)
	state.inventory.cadres.assign(SIX)
	state.inventory.consumables.assign(["grain_loan", "seizure_notice", "mutual_aid"])
	state.rationed = true
	state.coupons = 999
	state.resentment = 88
	_app.controller.reseal_book()
	var tall: Array[String] = ["on_combined_brigades", "on_launching_satellites"]
	_loop().visit.shop.stock_with(_loop().visit.shop.stock(), tall)
	# The black market's counter is set, not drawn, so a larger pool does not change what
	# the page is checked with; the Tally Clerk stands in its empty frame (ADR 0043).
	var counter: Array[String] = ["the_tally_clerk", "last_sheaf", "the_bookkeeper"]
	_loop().visit.market.stock_with(counter, _loop().visit.market.directive_stock())


func test_both_shops_fit_a_fresh_run() -> void:
	_loop().state.coupons = 60
	_app.controller.reseal_book()
	await _check_all("fresh")


func test_both_shops_fit_the_most_a_run_holds() -> void:
	_fill()
	await _check_all("full")
	var store: StoreScreen = _app.show_screen("store", true)
	await await_idle_frame()
	var board: NoticeBoard = store.board
	assert_int(board.slot_count()).is_equal(6)
	var stall: CampaignStall = store.campaign_stall
	assert_int(stall.tray.campaign_count()).is_equal(3)
	var reforms: ReformStall = store.reform_stall
	assert_int(reforms.strip.held_count()).is_equal(6)


func _check_all(where: String) -> void:
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		for screen_size: Vector2i in ClipCheck.SIZES:
			get_tree().root.size = screen_size
			for screen_id: String in ["store", "black_market"]:
				var store: StoreScreen = _app.show_screen(screen_id, true)
				await await_idle_frame()
				await await_idle_frame()
				var label: String = "%s %s %s" % [where, screen_id, screen_size]
				_check_inside(store, label)
				_check_blocks(store, label)
				_clips(store, label)


func _check_inside(root: Node, where: String) -> void:
	var screen: Rect2 = get_tree().root.get_visible_rect().grow(ClipCheck.SLACK)
	for node: Node in root.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if not control.is_visible_in_tree() or control is TextureRect or control is ColorRect:
			continue
		var rect: Rect2 = control.get_global_rect()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0 or rect.position.x < -1000.0:
			continue
		(
			assert_bool(screen.encloses(rect))
			. override_failure_message("%s: %s at %s" % [where, control.get_path(), rect])
			. is_true()
		)


func _check_blocks(store: StoreScreen, where: String) -> void:
	var blocks: Dictionary[String, Control] = store.blocks()
	assert_int(blocks.size()).is_equal(7)
	var names: Array[String] = blocks.keys()
	for first: int in names.size():
		for second: int in range(first + 1, names.size()):
			var a: Rect2 = blocks[names[first]].get_global_rect().grow(-ClipCheck.SLACK)
			var b: Rect2 = blocks[names[second]].get_global_rect().grow(-ClipCheck.SLACK)
			(
				assert_bool(a.intersects(b))
				. override_failure_message(
					"%s: %s %s overlaps %s %s" % [where, names[first], a, names[second], b]
				)
				. is_false()
			)


## Coming back from the black market shows the store again, whole, with its way out.
func test_returning_from_the_black_market_shows_the_store_whole() -> void:
	get_tree().root.size = ClipCheck.SIZES[0]
	_app.show_screen("store", true)
	await await_idle_frame()
	var market: StoreScreen = _app.show_screen("black_market")
	await await_idle_frame()
	var back: Button = null
	for node: Node in market.find_children("*", "Button", true, false):
		if (node as Button).text == tr("market.back"):
			back = node
	assert_object(back).is_not_null()
	back.pressed.emit()
	await await_idle_frame()
	await await_idle_frame()
	var switcher: SceneSwitcher = _app.get("switcher")
	var store: Node = switcher.current()
	assert_bool(store is StoreScreen).is_true()
	var leave: int = 0
	for node: Node in store.find_children("*", "Button", true, false):
		if (node as Button).text == tr("store.leave"):
			leave += 1
	assert_int(leave).is_equal(1)
	_check_inside(store, "returned store")


## The rank picker opens whole on the screen over the black market's counter, so its
## Cancel can be reached.
func test_the_rank_picker_opens_on_the_screen() -> void:
	for screen_size: Vector2i in ClipCheck.SIZES:
		get_tree().root.size = screen_size
		_loop().state.coupons = 40
		_app.controller.reseal_book()
		var offered: Array[String] = ["rehabilitation", "steel_target", "last_sheaf"]
		_loop().visit.market.stock_with(offered, _loop().visit.market.directive_stock())
		var market: StoreScreen = _app.show_screen("black_market", true)
		await await_idle_frame()
		var market_cadres: CadreCounter = market.cadres
		var counter: HBoxContainer = market_cadres.row
		var buy: Button = counter.get_child(0).find_children("*", "Button", true, false)[0]
		buy.pressed.emit()
		await await_idle_frame()
		var picker: RankPicker = market_cadres.picker
		assert_bool(picker.is_open()).is_true()
		var screen: Rect2 = get_tree().root.get_visible_rect().grow(ClipCheck.SLACK)
		assert_bool(screen.encloses(picker.get_global_rect())).is_true()
		picker.close()


## An envelope open over each shop fits both screens with three choices and with four,
## Supply Cooperative's: every visible piece on screen, no two papers overlapping, and
## the heading, row, explanation and Take Nothing apart.
func test_an_open_envelope_fits_with_three_and_four_choices() -> void:
	Settings.set_value("reduced_motion", true)
	for reforms: Array[String] in [[] as Array[String], ["supply_cooperative"] as Array[String]]:
		_loop().state.reforms.assign(reforms)
		for level: int in TextSize.count():
			Settings.set_value(TextSize.SETTING, level)
			for screen_size: Vector2i in ClipCheck.SIZES:
				get_tree().root.size = screen_size
				for kind: String in ["directive_envelope", "campaign_envelope", "parcel"]:
					var screen_id: String = "black_market" if kind == "parcel" else "store"
					_loop().state.coupons = 60
					_app.controller.reseal_book()
					_loop().visit.shop.envelopes.clear()
					_loop().visit.market.envelopes.clear()
					var stock: Array[String] = [kind]
					var counter: EnvelopeCounter = _loop().visit.market.envelopes
					if kind != "parcel":
						counter = _loop().visit.shop.envelopes
					counter.stock_with(stock)
					var store: StoreScreen = _app.show_screen(screen_id, true)
					await await_idle_frame()
					var stall: EnvelopeStall = store.envelope_stall
					stall.panel(0).buy.pressed.emit()
					await await_idle_frame()
					await await_idle_frame()
					var overlay: EnvelopeOverlay = stall.overlay()
					var label: String = "%s %s %d" % [kind, screen_size, 3 + reforms.size()]
					assert_int(overlay.papers().size()).is_equal(3 + reforms.size())
					_check_inside(overlay, label)
					_check_apart(overlay, label)
					_check_aligned(overlay, label)
					_clips(overlay, label)
					overlay.nothing_button().pressed.emit()
					await await_idle_frame()
	Settings.set_value("reduced_motion", false)


func _check_apart(overlay: EnvelopeOverlay, where: String) -> void:
	var pieces: Array[Control] = []
	for paper: ChoicePaper in overlay.papers():
		pieces.append(paper)
		var item: Rect2 = EnvelopeOverlay.shown_rect(paper.item)
		(
			assert_bool(paper.get_global_rect().grow(ClipCheck.SLACK).encloses(item))
			. override_failure_message("%s: item %s outside its paper" % [where, item])
			. is_true()
		)
		_check_paper(paper, overlay.papers().size(), where)
	var blocks: Dictionary[String, Control] = overlay.blocks()
	for block: String in ["heading", "detail", "button"]:
		if blocks.has(block):
			pieces.append(blocks[block])
	for first: int in pieces.size():
		for second: int in range(first + 1, pieces.size()):
			var a: Rect2 = pieces[first].get_global_rect().grow(-ClipCheck.SLACK)
			var b: Rect2 = pieces[second].get_global_rect().grow(-ClipCheck.SLACK)
			(
				assert_bool(a.intersects(b))
				. override_failure_message("%s: %s overlaps %s" % [where, a, b])
				. is_false()
			)


## A choice is the main thing on the screen: its item fills its place along one side, at
## the size the count of choices gives, and the item is its own button, with no face and
## exactly as wide as the paper; a caption sits on paper at a readable size, and nothing
## in a choice is faded.
func _check_paper(paper: ChoicePaper, count: int, where: String) -> void:
	var place: Vector2 = ChoicePaper.item_for(count)
	assert_bool(place.x >= (200.0 if count <= 3 else 190.0)).is_true()
	var item: Vector2 = EnvelopeOverlay.shown_rect(paper.item).size
	var fills: bool = item.x >= place.x * 0.85 or item.y >= place.y * 0.85
	(
		assert_bool(fills)
		. override_failure_message("%s: item %s in %s" % [where, item, place])
		. is_true()
	)
	var keep: Rect2 = paper.keep.get_global_rect()
	assert_float(absf(keep.size.x - paper.size.x)).override_failure_message(where).is_less(2.0)
	assert_str(paper.keep.text).override_failure_message(where).is_empty()
	var covered: bool = keep.grow(ClipCheck.SLACK).encloses(EnvelopeOverlay.shown_rect(paper.item))
	assert_bool(covered).override_failure_message(where + " button over item").is_true()
	if not paper.caption().is_empty():
		var label: Label = paper.caption_label()
		assert_int(label.get_theme_font_size("font_size")).is_greater_equal(16)
		assert_bool(paper.caption_strip().is_visible_in_tree()).is_true()
		var strip: Rect2 = paper.caption_strip().get_global_rect().grow(ClipCheck.SLACK)
		assert_bool(strip.encloses(label.get_global_rect())).is_true()
	var node: Node = paper.item
	while node != null and node != paper.get_parent():
		if node is CanvasItem:
			assert_float((node as CanvasItem).modulate.a).override_failure_message(where).is_equal(
				1.0
			)
		node = node.get_parent()


## Every choice in one envelope is one size with one top: the papers, and the items on
## them, a Directive's document as tall as a leaflet or a card, its whole text inside it
## with its Rate lines at 16 px or more.
func _check_aligned(overlay: EnvelopeOverlay, where: String) -> void:
	var papers: Array[ChoicePaper] = overlay.papers()
	var first: Rect2 = papers[0].get_global_rect()
	var first_item: Rect2 = EnvelopeOverlay.shown_rect(papers[0].item)
	for paper: ChoicePaper in papers:
		var rect: Rect2 = paper.get_global_rect()
		var item: Rect2 = EnvelopeOverlay.shown_rect(paper.item)
		var same: bool = (
			rect.size.is_equal_approx(first.size)
			and absf(rect.position.y - first.position.y) < 1.0
			and absf(item.size.y - first_item.size.y) < 1.0
			and absf(item.position.y - first_item.position.y) < 1.0
		)
		(
			assert_bool(same)
			. override_failure_message("%s: %s / %s, first %s" % [where, rect, item, first_item])
			. is_true()
		)
		if paper.lines.is_empty():
			continue
		var sheet: Control = paper.item.get_child(0) as Control
		(
			assert_bool(sheet.get_combined_minimum_size().y <= paper.item_size.y + 0.5)
			. override_failure_message("%s: %s overflows its document" % [where, paper.title])
			. is_true()
		)
		for line: Label in paper.lines:
			assert_int(line.get_theme_font_size("font_size")).is_greater_equal(16)


## Every Directive's document fits an envelope's smaller place whole: no Rate line, at
## 16 px or more, runs past its bottom.
func test_every_directive_document_fits_the_smaller_place() -> void:
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		for directive: DirectiveDef in RunPools.DIRECTIVES.directives:
			var paper: ChoicePaper = auto_free(ChoicePaper.new())
			# Under the app, so the game's theme sets its type.
			_app.add_child(paper)
			paper.setup(0, ChoicePaper.ITEM_MANY)
			paper.show_directive(_app.controller, directive.id)
			await await_idle_frame()
			var sheet: Control = paper.item.get_child(0) as Control
			(
				assert_float(sheet.get_combined_minimum_size().y)
				. override_failure_message(directive.id)
				. is_less_equal(ChoicePaper.ITEM_MANY.y + 0.5)
			)
			assert_vector(paper.item.size).is_equal(ChoicePaper.ITEM_MANY)
			for line: Label in paper.lines:
				assert_int(line.get_theme_font_size("font_size")).is_greater_equal(16)


## Nothing under root clips, as ClipCheck says (ADR 0034).
func _clips(root: Node, where: String) -> void:
	var problems: PackedStringArray = []
	ClipCheck.check(root, "%s at text size %d" % [where, TextSize.level()], problems)
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()


## Each shop at its worst (ADR 0034): every other shelf at its fullest, and the counter
## holding the three Cadres of that shop's own pool with the longest rules, then the three
## with the longest names, found from the data. At both screens and every text size the
## page fits, no two blocks overlap and no text is clipped.
func test_both_shops_fit_their_longest_cadres() -> void:
	_fill()
	for market: bool in [false, true]:
		var pool: CadrePool = RunPools.MARKET_CADRES if market else RunPools.STORE_CADRES
		for measure: Callable in [_rule_length, _name_length]:
			var counter: Array[String] = _longest(pool, measure)
			var shop: RunShop = _loop().visit.market if market else _loop().visit.shop
			shop.stock_with(counter, shop.directive_stock())
			var screen_id: String = "black_market" if market else "store"
			for level: int in TextSize.count():
				Settings.set_value(TextSize.SETTING, level)
				for screen_size: Vector2i in ClipCheck.SIZES:
					get_tree().root.size = screen_size
					var store: StoreScreen = _app.show_screen(screen_id, true)
					await await_idle_frame()
					await await_idle_frame()
					var label: String = "%s %s %s" % [screen_id, counter, screen_size]
					_check_inside(store, label)
					_check_blocks(store, label)
					_clips(store, label)


## The three Cadres of pool that measure longest.
func _longest(pool: CadrePool, measure: Callable) -> Array[String]:
	var ids: Array[String] = []
	for cadre: ModifierDef in pool.cadres:
		ids.append(cadre.id)
	ids.sort_custom(func(a: String, b: String) -> bool: return measure.call(a) > measure.call(b))
	return ids.slice(0, 3)


func _rule_length(cadre_id: String) -> int:
	return ScreenKit.rule_text(_app.controller, cadre_id).length()


func _name_length(cadre_id: String) -> int:
	return _app.controller.texts.modifier_name(cadre_id).length()
