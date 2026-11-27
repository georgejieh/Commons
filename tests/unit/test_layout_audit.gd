extends GdUnitTestSuite
## The playtest's layout audit (tools/layout_audit.gd) finds each kind of fault it is
## there for, and passes a clean page: text over text, text partly under another paper,
## text cut by its own box, text that leaves the screen or its paper, and small type.

const AUDIT: GDScript = preload("res://tools/layout_audit.gd")

var _page: Control


func before_test() -> void:
	_page = auto_free(Control.new())
	_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page.size = Vector2(1920, 1080)
	get_tree().root.add_child(_page)


func _label(text: String, at: Vector2, parent: Control = null) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	(parent if parent != null else _page).add_child(label)
	label.position = at
	return label


func _paper(at: Rect2) -> Panel:
	var paper: Panel = Panel.new()
	paper.add_theme_stylebox_override("panel", StyleBoxFlat.new())
	_page.add_child(paper)
	paper.position = at.position
	paper.size = at.size
	return paper


func _found() -> String:
	await await_idle_frame()
	await await_idle_frame()
	var audit: RefCounted = AUDIT.new()
	var lines: PackedStringArray = audit.call("check", get_tree().root)
	var mine: PackedStringArray = []
	for line: String in lines:
		if line.contains("audit-"):
			mine.append(line)
	return "\n".join(mine)


func test_a_clean_page_has_no_finding() -> void:
	_label("audit-one", Vector2(100, 100))
	_label("audit-two", Vector2(100, 200))
	assert_str(await _found()).is_empty()


func test_text_over_text_is_found() -> void:
	_label("audit-under words", Vector2(100, 100))
	_label("audit-over words", Vector2(140, 108))
	assert_str(await _found()).contains("OVERLAP")


func test_text_partly_under_another_paper_is_found() -> void:
	_label("audit-covered line of words", Vector2(100, 100))
	_paper(Rect2(220, 60, 400, 200))
	assert_str(await _found()).contains("COVERED")


func test_text_cut_by_its_box_is_found() -> void:
	var cut: Label = _label("audit-cut " + "word ".repeat(40), Vector2(100, 100))
	cut.autowrap_mode = TextServer.AUTOWRAP_WORD
	cut.clip_text = true
	cut.size = Vector2(200, 40)
	assert_str(await _found()).contains("CLIPPED")


func test_text_off_the_screen_or_its_paper_is_found() -> void:
	_label("audit-off the screen", Vector2(1850, 100))
	var sheet: Panel = _paper(Rect2(300, 500, 200, 80))
	_label("audit-off its paper by far", Vector2(60, 20), sheet)
	var found: String = await _found()
	assert_str(found).contains("OFFSCREEN")
	assert_str(found).contains("OFF-PAPER")


func test_small_type_is_found() -> void:
	var small: Label = _label("audit-small", Vector2(100, 100))
	small.add_theme_font_size_override("font_size", 12)
	assert_str(await _found()).contains("SMALL")


func test_a_slip_over_the_row_it_explains_is_by_design_but_over_another_is_found() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	_page.add_child(row)
	row.position = Vector2(100, 400)
	var explained: Label = _label("audit-the card explained", Vector2.ZERO, row)
	var neighbour_label: Label = _label("audit-its neighbour", Vector2.ZERO, row)
	var elsewhere: Label = _label("audit-another page's line", Vector2(100, 700))
	var slip: DetailSlip = DetailSlip.new()
	_page.add_child(slip)
	slip.show_for(explained, "slip title", "slip rule")
	await await_idle_frame()
	var neighbour: Rect2 = neighbour_label.get_global_rect()
	slip.global_position = neighbour.position + Vector2(neighbour.size.x * 0.5, -10.0)
	var found: String = await _found()
	assert_str(found).not_contains("audit-its neighbour")
	slip.global_position = elsewhere.global_position + Vector2(elsewhere.size.x * 0.5, -10.0)
	assert_str(await _found()).contains('COVERED "audit-another page')


func test_cards_of_one_fan_are_by_design_but_another_paper_over_a_card_is_found() -> void:
	var kind: GDScript = GDScript.new()
	kind.source_code = "extends Control\n"
	assert_int(kind.reload()).is_equal(OK)
	var fan: Control = Control.new()
	_page.add_child(fan)
	var under: Control = _card(fan, kind, "audit-the card under", Vector2(100, 100))
	_card(fan, kind, "audit-the card over", Vector2(220, 60))
	assert_str(await _found()).not_contains("COVERED")
	under.position = Vector2(100, 400)
	var stranger: Control = _card(fan, null, "audit-a stranger", Vector2(220, 360))
	assert_object(stranger).is_not_null()
	assert_str(await _found()).contains('COVERED "audit-the card under')


## A card: its words, and over them a paper of its own, as a card's face is.
func _card(fan: Control, kind: GDScript, words: String, at: Vector2) -> Control:
	var card: Control = Control.new()
	card.set_script(kind)
	fan.add_child(card)
	card.position = at
	_label(words, Vector2.ZERO, card)
	var face: Panel = Panel.new()
	face.add_theme_stylebox_override("panel", StyleBoxFlat.new())
	card.add_child(face)
	face.position = Vector2(0, 40)
	face.size = Vector2(400, 200)
	return card
