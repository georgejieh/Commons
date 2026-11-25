extends GdUnitTestSuite
## Grime never costs readability (art/STYLE.md, "Nothing is clean"): names and rules the
## player must read are dark type at 16 px or more on a 1080 screen, and nothing a rule
## depends on is shown by hover alone. Shop Cadre cards print their full rules; Campaign
## leaflets keep their names large; the Reforms strip and the board's names fit without
## clipping; a card's marks sit in the strip a fanned hand leaves showing; the rank picker
## stands over a scrim; paper is never shorter than its own printed border; and the
## collection and the village history each sit on one sheet with the shops' heading colour.

const SEED: int = 4242
const SAVE_PATH: String = "user://test_readability/run.json"
const CARD_SCENE: PackedScene = preload("res://ui/cards/card_view.tscn")
## The least type that reads on a 1080 screen, and the least a board name may shrink to.
const READABLE: int = 16
const SHRUNK: int = 14
## How much of a card's left edge a fanned hand leaves showing, in card pixels.
const FAN_STRIP: float = 57.0

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


func after_test() -> void:
	Settings.set_value(TextSize.SETTING, 0)
	get_tree().root.size = _was_size
	Saves.run_service().delete()
	Saves.profile_service().delete()


func _to_store() -> void:
	var driver: ControllerScript = ControllerScript.new()
	while _app.controller.awaiting() != RunController.AWAIT_SET_OVER:
		driver.act(_app.controller)
	_app.controller.finish_set()


func _open(screen_id: String) -> StoreScreen:
	var store: StoreScreen = _app.show_screen(screen_id, true)
	await await_idle_frame()
	await await_idle_frame()
	return store


func test_shop_cadre_cards_print_their_rules_under_art_or_its_frame() -> void:
	_to_store()
	var loop: RunLoop = _app.controller.run_loop()
	var offered: Array[String] = ["rehabilitation", "hidden_reserves", "last_sheaf"]
	loop.market.set("_stock", offered)
	for screen_id: String in ["store", "black_market"]:
		var store: StoreScreen = await _open(screen_id)
		var counter: HBoxContainer = store.get("_counter")
		var stock: Array[String] = _app.controller.desk(screen_id == "black_market").stock()
		for slot: int in stock.size():
			var card: Control = counter.get_child(slot)
			var rules: Array[Node] = card.find_children("*", "KeywordText", true, false)
			assert_int(rules.size()).is_equal(1)
			var text: KeywordText = rules[0]
			assert_str(text.get_parsed_text()).is_not_empty()
			assert_int(text.get_theme_font_size("normal_font_size")).is_greater_equal(READABLE)
			var framed: int = card.find_children("*", "ArtFrame", true, false).size()
			var pictured: int = card.find_children("*", "TextureRect", true, false).size()
			assert_int(framed + pictured).is_greater_equal(1)
			if not ScreenKit.ART.has_cadre(stock[slot]):
				assert_int(framed).is_equal(1)
			var name: String = tr("modifier.%s.name" % stock[slot])
			var shown: bool = false
			for node: Node in card.find_children("*", "Label", true, false):
				var label: Label = node
				if label.text == name:
					shown = true
					assert_int(label.get_theme_font_size("font_size")).is_greater_equal(READABLE)
			assert_bool(shown).override_failure_message(name).is_true()
			assert_bool(text.get_global_rect().end.y <= card.get_global_rect().end.y).is_true()


## Paper panels are never shorter or narrower than their own printed border, so a border
## line never crosses the words on them.
func test_shop_paper_is_never_shorter_than_its_border() -> void:
	_to_store()
	for screen_id: String in ["store", "black_market"]:
		var store: StoreScreen = await _open(screen_id)
		for node: Node in store.find_children("*", "PanelContainer", true, false):
			var panel: PanelContainer = node
			var style: StyleBoxTexture = panel.get_theme_stylebox("panel") as StyleBoxTexture
			if style == null or not panel.is_visible_in_tree():
				continue
			var least: Vector2 = Vector2(
				style.texture_margin_left + style.texture_margin_right,
				style.texture_margin_top + style.texture_margin_bottom
			)
			(
				assert_bool(panel.size.x >= least.x and panel.size.y >= least.y)
				. override_failure_message("%s %s" % [panel.get_path(), panel.size])
				. is_true()
			)


func test_campaign_leaflets_keep_their_names_readable_and_strong() -> void:
	for compact: bool in [false, true]:
		var leaflet: CampaignLeaflet = auto_free(CampaignLeaflet.new())
		add_child(leaflet)
		leaflet.set_compact(compact)
		leaflet.show_campaign(0, "registration_drive", "Registration Drive", "rule", true)
		leaflet.set_reason(1, "why")
		assert_float(leaflet.modulate.a).is_equal(1.0)
		for node: Node in leaflet.find_children("*", "Label", true, false):
			var label: Label = node
			if label.text == "Registration Drive":
				assert_int(label.get_theme_font_size("font_size")).is_greater_equal(READABLE)
				assert_object(label.get_theme_color("font_color")).is_equal(ScreenKit.INK)


func test_the_reforms_strip_and_board_names_fit_without_clipping() -> void:
	assert_int(ReformStrip.NAME_SIZE).is_greater_equal(READABLE)
	_to_store()
	var loop: RunLoop = _app.controller.run_loop()
	loop.state.reforms.assign(["supply_cooperative", "work_point_reform", "couriers_bag"])
	var store: StoreScreen = await _open("store")
	var stall: ReformStall = store.get("_reform_stall")
	var strip: ReformStrip = stall.strip
	var notes: Control = store.blocks()["notes"]
	assert_float(strip.size.x).is_greater(notes.size.x - 2.0)
	var font: Font = strip.get_theme_default_font()
	# The narrowest a board's name may be set in: a card of a full board of six.
	var board: NoticeBoard = auto_free(NoticeBoard.new())
	add_child(board)
	board.setup(6, StoreScreen.BOARD_BOX)
	var tile: float = board.tile_size(6).x - CadreBadge.NAME_MARGIN * 2.0
	# Cadre names only: the board shows nothing else ("Overfulfillment" is a Campaign).
	for word: String in ["Rehabilitation", "Stakhanovite"]:
		var fitted: int = CadreBadge.name_size(font, word, tile)
		assert_int(fitted).is_greater_equal(SHRUNK)
		var width: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x
		assert_float(width).override_failure_message(word).is_less_equal(tile)


## Both marks sit down the card's left edge, which a fanned hand leaves showing, clear of
## each other and of the rank note.
func test_card_marks_sit_in_the_strip_a_fan_leaves_showing() -> void:
	var view: CardView = auto_free(CARD_SCENE.instantiate())
	add_child(view)
	var card: CardInstance = Deck.new().card(41)
	CardModifiers.stamp(card, 0)
	CardModifiers.enhance(card, CardInstance.MODEL)
	view.bind(card)
	await await_idle_frame()
	var boxes: Array[Rect2] = []
	for node: Node in view.get_node("Frame").get_children():
		if node is CardMark:
			var box: Rect2 = (node as Control).get_rect()
			assert_float(box.end.x).is_less_equal(FAN_STRIP + 13.0)
			assert_float(box.position.x).is_less(FAN_STRIP / 2.0)
			boxes.append(box)
	assert_int(boxes.size()).is_equal(2)
	assert_bool(boxes[0].intersects(boxes[1])).is_false()


func test_the_rank_picker_stands_over_a_scrim() -> void:
	_to_store()
	var store: StoreScreen = await _open("black_market")
	var picker: RankPicker = store.get("_picker")
	picker.ask("Pick", store, func(_rank: int) -> void: pass)
	await await_idle_frame()
	var scrim: Scrim = picker.scrim()
	assert_bool(scrim.is_visible_in_tree()).is_true()
	assert_int(scrim.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	var screen: Rect2 = Rect2(Vector2.ZERO, Vector2(1920, 1080))
	assert_bool(scrim.get_global_rect().encloses(screen)).is_true()
	assert_float(RankChip.LIFT).is_greater_equal(8.0)
	picker.close()


## A profile with every tier open, so the collection shows every item.
func _open_everything() -> void:
	var data: ProfileData = Profile.read(Saves.profile_service())
	# Past the last tier (ADR 0032), so every Cadre's sheet is open.
	data.finished_runs = RunUnlocks.LAST_TIER
	Profile.write(Saves.profile_service(), data)


func test_the_collection_sits_on_one_sheet_with_a_red_heading() -> void:
	_open_everything()
	var collection: CollectionScreen = _app.show_screen("collection")
	await await_idle_frame()
	await await_idle_frame()
	var scroll: ScrollContainer = collection.scroll()
	var sheet: Control = scroll.get_parent().get_parent() as Control
	assert_bool(sheet is PanelContainer).is_true()
	assert_bool(sheet.get_global_rect().encloses(scroll.get_global_rect())).is_true()
	var frames: int = collection.find_children("*", "ArtFrame", true, false).size()
	var bare: int = 0
	for cadre: ModifierDef in RunLoop.all_cadres():
		if not ScreenKit.ART.has_cadre(cadre.id):
			bare += 1
	assert_int(frames).is_equal(bare)
	for node: Node in collection.find_children("*", "Label", true, false):
		var label: Label = node
		if label.text == tr("coll.title"):
			assert_object(label.get_theme_color("font_color")).is_equal(ScreenKit.RED)


func test_the_village_history_sits_on_one_sheet_with_a_red_heading() -> void:
	var history: VillageHistoryScreen = _app.show_screen("village_history")
	await await_idle_frame()
	await await_idle_frame()
	var sheet: PanelContainer = history.sheet()
	assert_bool(sheet.get_global_rect().encloses(history.scroll().get_global_rect())).is_true()
	var headings: int = 0
	for node: Node in sheet.find_children("*", "Label", true, false):
		var label: Label = node
		if label.text in [tr("hist.eyebrow"), tr("hist.title"), tr("hist.past")]:
			assert_object(label.get_theme_color("font_color")).is_equal(ScreenKit.RED)
			headings += 1
		elif not label.text.is_empty() and not label.get_parent() is Button:
			assert_float(label.get_theme_color("font_color").get_luminance()).is_less(0.35)
			assert_int(label.get_theme_font_size("font_size")).is_greater_equal(READABLE)
	assert_int(headings).is_equal(3)


## Every name, through every paper that prints it, breaks only between words: a word
## wider than its paper shrinks the name instead.
func test_no_name_breaks_inside_a_word() -> void:
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		for campaign: CampaignDef in RunCampaigns.all():
			var name: String = tr(campaign.name_key)
			for compact: bool in [false, true]:
				var leaflet: CampaignLeaflet = auto_free(CampaignLeaflet.new())
				add_child(leaflet)
				leaflet.set_compact(compact)
				leaflet.show_campaign(0, campaign.id, name, "", false)
				await await_idle_frame()
				_assert_fits(leaflet.name_label(), "leaflet %s" % compact)
				_clips(leaflet, "leaflet %s %s" % [campaign.id, compact])
			await _check_panel(name)
			for count: int in [3, 4]:
				var paper: ChoicePaper = await _choice(count)
				paper.show_campaign(_app.controller, campaign.id)
				await await_idle_frame()
				_assert_fits(_named(paper, name), "campaign choice %d" % count)
				_clips(paper, "campaign choice %s %d" % [campaign.id, count])
		for reform: ReformDef in RunReforms.all():
			await _check_panel(tr(reform.name_key))
		for params: ShopParams in [RunPools.STORE, RunPools.MARKET]:
			for envelope: EnvelopeDef in params.envelopes:
				await _check_panel(tr(envelope.name_key))
		for directive: DirectiveDef in RunPools.DIRECTIVES.directives:
			for count: int in [3, 4]:
				var paper: ChoicePaper = await _choice(count)
				paper.show_directive(_app.controller, directive.id)
				await await_idle_frame()
				_assert_fits(_named(paper, tr(directive.name_key)), "directive %d" % count)
				_clips(paper, "directive choice %s %d" % [directive.id, count])
		await _check_cadres()


func _check_cadres() -> void:
	var board: NoticeBoard = auto_free(NoticeBoard.new())
	add_child(board)
	board.setup(6, StoreScreen.BOARD_BOX)
	var tile: float = board.tile_size(6).x - CadreBadge.NAME_MARGIN * 2.0
	var font: Font = board.get_theme_default_font()
	for cadre: ModifierDef in RunLoop.all_cadres():
		var name: String = tr(cadre.name_key)
		var words: VBoxContainer = auto_free(VBoxContainer.new())
		words.custom_minimum_size = Vector2(StoreScreen.CARD.x - 48.0, 0)
		add_child(words)
		words.add_child(StoreCard.words(name, "rule"))
		await await_idle_frame()
		_assert_fits(_named(words, name), "store card")
		_clips(words, "store card %s" % name)
		var fitted: int = CadreBadge.name_size(font, name, tile)
		(
			assert_bool(NameFit.words_fit(font, name, tile, fitted))
			. override_failure_message(name)
			. is_true()
		)
	_open_everything()
	var collection: CollectionScreen = _app.show_screen("collection")
	await await_idle_frame()
	await await_idle_frame()
	for cadre: ModifierDef in RunLoop.all_cadres():
		_assert_fits(_named(collection, tr(cadre.name_key)), "collection")
	_clips(collection, "collection with everything open")


func _check_panel(name: String) -> void:
	var panel: CounterPanel = auto_free(CounterPanel.new())
	add_child(panel)
	panel.offer(CounterPanel.Look.LEAFLET, "KIND", "id", name, "rule", "Buy")
	await await_idle_frame()
	_assert_fits(panel.name_label(), "counter panel")
	_clips(panel, "counter panel %s" % name)


func _choice(count: int) -> ChoicePaper:
	var paper: ChoicePaper = auto_free(ChoicePaper.new())
	paper.setup(0, ChoicePaper.item_for(count))
	add_child(paper)
	await await_idle_frame()
	return paper


## The label under root that prints name.
func _named(root: Node, name: String) -> Label:
	for node: Node in root.find_children("*", "Label", true, false):
		if (node as Label).text == name:
			return node as Label
	return null


func _assert_fits(label: Label, where: String) -> void:
	assert_object(label).override_failure_message(where).is_not_null()
	if label == null:
		return
	(
		assert_bool(NameFit.label_fits(label))
		. override_failure_message(
			(
				"%s: %s at %d px in %s"
				% [where, label.text, label.get_theme_font_size("font_size"), label.size]
			)
		)
		. is_true()
	)


## Multiples print as rules text has them: a whole one with no decimal.
func test_whole_multiples_print_without_a_decimal() -> void:
	assert_str(ModifierDef.multiple(2.0)).is_equal("2")
	assert_str(ModifierDef.multiple(1.5)).is_equal("1.5")
	var card: CardInstance = Deck.new().card(20)
	var caption: String = _app.controller.envelope_card_text(
		EnvelopeShelf.KIND_MODEL, "caption", card
	)
	assert_str(caption).contains("2 times")
	assert_str(caption).not_contains("2.0")


## Nothing under root clips, as ClipCheck says (ADR 0034).
func _clips(root: Node, where: String) -> void:
	var problems: PackedStringArray = []
	ClipCheck.check(root, "%s at text size %d" % [where, TextSize.level()], problems)
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()
