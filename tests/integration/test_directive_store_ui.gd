extends GdUnitTestSuite
## The state store's Directive column (ADR 0021): each document names its Rate change for
## every hand type it raises, from the same table the scorer uses; issuing one seals it,
## ticks the Rates, holds rerolls while it is acted out, then files it away, and under
## reduced motion goes straight to the result. The cheat sheet shows the raised Rate and
## its level. A card view shows a stamp's chop and a Model card's rosette, clear of the
## rank note and the selection edge.

const SEED: int = 4242
const CARD_SCENE: PackedScene = preload("res://ui/cards/card_view.tscn")
## Seconds an issue may take to act out before the test gives up on it.
const ISSUE_SECONDS: float = 4.0
## How far inside the card's edge a mark stays, past the selection edge's width.
const EDGE_INSET: float = 6.0

var _app: App
var _was_size: Vector2i


func before_test() -> void:
	# The layout is measured at the size the store is drawn for.
	_was_size = get_tree().root.size
	get_tree().root.size = Vector2i(1920, 1080)
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)
	_app.new_run(SEED)
	var driver: ControllerScript = ControllerScript.new()
	driver.play_to(self, _app.controller, RunController.AWAIT_SET_OVER)
	_app.controller.finish_set()


func after_test() -> void:
	get_tree().root.size = _was_size
	Settings.set_value("reduced_motion", false)
	Saves.run_service().delete()


func _open_store() -> StoreScreen:
	var store: StoreScreen = _app.show_screen(ScreenId.STORE, true)
	await await_idle_frame()
	return store


func _row(store: StoreScreen) -> DirectiveRow:
	return store.directives


func _documents(row: DirectiveRow) -> Array[Control]:
	var documents: Array[Control] = []
	for child: Node in row.get_children():
		if child is PanelContainer:
			documents.append(child as Control)
	return documents


func _texts(root: Node) -> PackedStringArray:
	var texts: PackedStringArray = []
	for child: Node in root.find_children("*", "Label", true, false):
		texts.append((child as Label).text)
	return texts


func _type_name(type: int) -> String:
	return tr("pattern." + String(Pattern.Type.keys()[type]).to_lower())


## The first Directive the coupons allow, by slot, and its issue button.
func _affordable(row: DirectiveRow) -> Button:
	for button: Node in row.find_children("*", "Button", true, false):
		var ticket: Button = button as Button
		if ticket.theme_type_variation == CommonsTheme.COUPON and not ticket.disabled:
			return ticket
	return null


func test_the_store_shows_each_directive_with_its_rate_lines() -> void:
	var store: StoreScreen = await _open_store()
	var row: DirectiveRow = _row(store)
	assert_object(row).is_not_null()
	var stock: Array[String] = _app.controller.store.desk(false).directive_stock()
	assert_int(stock.size()).is_equal(2)
	var documents: Array[Control] = _documents(row)
	assert_int(documents.size()).is_equal(stock.size())
	var controller: RunController = _app.controller
	for slot: int in stock.size():
		var texts: PackedStringArray = _texts(documents[slot])
		assert_array(Array(texts)).contains([tr("directive.eyebrow").to_upper()])
		assert_array(Array(texts)).contains([controller.texts.directive_name(stock[slot])])
		for type: int in controller.items.directive_types(stock[slot]):
			var line: String = (
				tr("directive.rate")
				. format(
					{
						"type": _type_name(type),
						"from": controller.figures.hand_rate(type, 1),
						"to": controller.figures.hand_rate(type, 2),
					}
				)
			)
			assert_array(Array(texts)).contains([line])
	# The black market issues none.
	var market: StoreScreen = _app.show_screen(ScreenId.BLACK_MARKET)
	await await_idle_frame()
	assert_object(_row(market)).is_null()


func test_issuing_seals_ticks_holds_rerolls_and_files_the_document() -> void:
	var store: StoreScreen = await _open_store()
	var row: DirectiveRow = _row(store)
	var ticket: Button = _affordable(row)
	assert_object(ticket).is_not_null()
	var stock: Array[String] = _app.controller.store.desk(false).directive_stock()
	var was: int = _app.controller.state_copy().coupons
	ticket.pressed.emit()
	var issued: String = ""
	for directive_id: String in stock:
		if not _app.controller.store.desk(false).directive_stock().has(directive_id):
			issued = directive_id
	assert_str(issued).is_not_empty()
	assert_int(_app.controller.state_copy().coupons).is_less(was)
	assert_bool(row.is_busy()).is_true()
	assert_bool(store.is_issuing()).is_true()
	assert_bool(row.seal().visible).is_true()
	assert_str(row.seal().word()).is_equal(tr("directive.issued").to_upper())
	_check_seal_clear(row, ticket)
	# A reroll waits for the issue: the counter keeps its stock and its coupons.
	var coupons: int = _app.controller.state_copy().coupons
	store.reroll.pressed.emit()
	assert_int(_app.controller.state_copy().coupons).is_equal(coupons)
	var issued_out: Callable = func() -> bool: return not row.is_busy()
	await TestWait.until(self, issued_out, "the Directive's issue", ISSUE_SECONDS)
	assert_bool(row.seal().visible).is_false()
	for type: int in _app.controller.items.directive_types(issued):
		assert_int(_app.controller.figures.hand_level(type)).is_equal(2)
	await await_idle_frame()
	assert_array(Array(_texts(row))).contains([tr("directive.issued")])
	assert_int(_documents(row).size()).is_equal(stock.size())


## At 1920x1080 the seal presses on the spent Buy ticket, at the document's top right,
## and covers neither the name nor a Rate line.
func _check_seal_clear(row: DirectiveRow, ticket: Button) -> void:
	assert_vector(get_tree().root.get_visible_rect().size).is_equal(Vector2(1920, 1080))
	var seal: Rect2 = row.seal().get_global_rect()
	var middle: Vector2 = ticket.get_global_rect().get_center()
	assert_bool(seal.has_point(middle)).is_true()
	var document: Control = ticket.get_parent()
	while not document is PanelContainer:
		document = document.get_parent()
	var labels: Array[Node] = document.find_children("*", "Label", true, false)
	for node: Node in labels:
		var label: Label = node as Label
		if label.text.is_empty() or label.get_parent() == ticket:
			continue
		var font: Font = label.get_theme_font("font")
		var font_size: int = label.get_theme_font_size("font_size")
		var wide: float = (
			font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		)
		var printed: Rect2 = Rect2(label.global_position, Vector2(wide, label.size.y))
		assert_bool(seal.intersects(printed)).override_failure_message(label.text).is_false()


func test_reduced_motion_issues_at_once() -> void:
	Settings.set_value("reduced_motion", true)
	var store: StoreScreen = await _open_store()
	var row: DirectiveRow = _row(store)
	var ticket: Button = _affordable(row)
	assert_object(ticket).is_not_null()
	ticket.pressed.emit()
	assert_bool(row.is_busy()).is_false()
	assert_bool(row.seal().visible).is_false()
	assert_bool(store.is_issuing()).is_false()
	await await_idle_frame()
	assert_array(Array(_texts(row))).contains([tr("directive.issued")])


func test_the_cheat_sheet_shows_the_raised_rate_and_level() -> void:
	var store: StoreScreen = await _open_store()
	Settings.set_value("reduced_motion", true)
	var ticket: Button = _affordable(_row(store))
	assert_object(ticket).is_not_null()
	var stock: Array[String] = _app.controller.store.desk(false).directive_stock()
	ticket.pressed.emit()
	var issued: String = (
		stock[0] if _app.controller.store.desk(false).directive_stock()[0] == "" else ""
	)
	if issued.is_empty():
		issued = stock[1]
	var sheet: CheatSheet = auto_free(CheatSheet.new())
	add_child(sheet)
	sheet.toggle(_app.controller)
	var controller: RunController = _app.controller
	var raised: Array[int] = controller.items.directive_types(issued)
	for type: int in range(1, Pattern.Type.size()):
		var level: int = 2 if raised.has(type) else 1
		var rate: int = controller.figures.hand_rate(type, level)
		var expected: String = tr("cheat.rate").format({"rate": rate})
		if level > 1:
			expected = tr("cheat.rate.level").format({"rate": rate, "level": level})
		assert_str(sheet.rate_text(type)).is_equal(expected)


func test_a_card_view_shows_each_mark_clear_of_the_note_and_edge() -> void:
	var view: CardView = auto_free(CARD_SCENE.instantiate())
	add_child(view)
	var plain: CardInstance = Deck.new().card(20)
	view.bind(plain)
	assert_bool(view.shows_stamp()).is_false()
	assert_that(view.shown_enhancement()).is_not_equal(CardInstance.MODEL)
	var marked: CardInstance = Deck.new().card(20)
	CardModifiers.stamp(marked, 0)
	view.bind(marked)
	assert_bool(view.shows_stamp()).is_true()
	assert_that(view.shown_enhancement()).is_not_equal(CardInstance.MODEL)
	CardModifiers.enhance(marked, CardInstance.MODEL)
	view.bind(marked)
	assert_bool(view.shows_stamp()).is_true()
	assert_that(view.shown_enhancement()).is_equal(CardInstance.MODEL)
	# The generic enhancement bar is not drawn under a rosette.
	var bar: Control = view.get_node("Frame/Enhancement")
	assert_bool(bar.visible).is_false()
	view.set_rank_note(tr("card.rank_as").format({"rank": "3"}))
	await await_idle_frame()
	var card: Rect2 = Rect2(Vector2.ZERO, view.size).grow(-EDGE_INSET)
	var note: Rect2 = (view.get_node("Frame/RankNote") as Control).get_rect()
	var rank: Label = view.get_node("Frame/Rank")
	for mark: Node in view.get_node("Frame").get_children():
		if mark is CardMark:
			var box: Rect2 = (mark as Control).get_rect()
			assert_bool(card.encloses(box)).override_failure_message(str(box)).is_true()
			assert_bool(box.intersects(note)).override_failure_message(str(box)).is_false()
			# Clear of the widest rank glyph, a joker's word.
			var font: Font = rank.get_theme_font("font")
			for key: String in CardView.RANK_KEYS:
				var size: int = (
					CardView.JOKER_SIZE if key.contains("joker") else CardView.GLYPH_SIZE
				)
				var wide: float = (
					font.get_string_size(tr(key), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
				)
				var glyph: Rect2 = Rect2(rank.position, Vector2(wide, size))
				assert_bool(box.intersects(glyph)).override_failure_message(key).is_false()
