extends RefCounted
## Looks over everything on screen for layout faults a person would see (P5.2a), so the
## playtest's walk finds them on every screen it visits and not only where a layout test
## was written: text cut off by its box, a piece of text or a panel partly off the screen,
## text that runs out of the paper it is on, text drawn over other text, text partly under
## another paper, and type under 16 px. It reads the tree and never changes it. What is
## behind a full-screen dim (a dialog or an open envelope over a page) is not compared
## with what is in front of it, nor what a large sheet covers with the sheet; cards in a
## fan cover one another on purpose; and what a ScrollContainer cuts off is scrolled.
## A finding is a line to read, not a failure: a slip that explains a card covers part of
## the page on purpose. Each is reported once a run.
## Loaded at run time by playtest.gd; it names no ui/ class. Development only.

const SLACK: float = 2.0
## Two texts overlap when their boxes share at least this much, each way.
const OVERLAP: float = 6.0
## A paper covers a text when it hides between these shares of it: less is a touch, and
## all of it is a text put away on purpose.
const COVERED: Vector2 = Vector2(0.12, 0.92)
const LEAST_TYPE: float = 15.5
## A piece this faint is still arriving or is put away.
const FAINT: float = 0.35
## A full-screen piece covers at least this share of the screen.
const CURTAIN: float = 0.95
## A paper this share of the screen or more is a sheet laid over the page on purpose.
const SHEET: float = 0.12
const SNIPPET: int = 28

var _seen: Dictionary[String, bool] = {}
var _screen: Rect2
## One entry per text and per paper, in the order they are drawn.
var _texts: Array[Dictionary] = []
var _papers: Array[Dictionary] = []
var _curtains: Array[int] = []
var _count: int = 0


## Every new finding on the screen now, each as one line.
func check(root: Window) -> PackedStringArray:
	_screen = Rect2(Vector2.ZERO, root.get_visible_rect().size)
	_texts.clear()
	_papers.clear()
	_curtains.clear()
	_count = 0
	for child: Node in root.get_children():
		_walk(child, 1.0, 0, 0, _screen.grow(4096.0), false, null)
	var found: PackedStringArray = []
	for text: Dictionary in _texts:
		_check_text(text, found)
	_check_pairs(found)
	_check_covered(found)
	return found


func _walk(
	node: Node, alpha: float, layer: int, z: int, clip: Rect2, clipped: bool, paper: Control
) -> void:
	if node is Window:
		return
	var canvas_layer: CanvasLayer = node as CanvasLayer
	if canvas_layer != null:
		if not canvas_layer.visible:
			return
		layer = canvas_layer.layer
		z = 0
	var item: CanvasItem = node as CanvasItem
	if item != null:
		if not item.visible:
			return
		alpha *= item.modulate.a
		z = (z if item.z_as_relative else 0) + item.z_index
	if alpha < FAINT:
		return
	_count += 1
	var control: Control = node as Control
	if control != null:
		var order: int = layer * 100000000 + (z + 4096) * 10000 + _count
		var box: Rect2 = _global(control, Rect2(Vector2.ZERO, control.size))
		if _is_paper(control):
			paper = control
			_papers.append({"node": control, "box": box.intersection(clip), "order": order})
		elif _is_curtain(control, box):
			_curtains.append(order)
		if _has_text(control):
			(
				_texts
				. append(
					{
						"node": control,
						"box": _text_box(control).intersection(clip),
						"whole": _text_box(control),
						"order": order,
						"paper": paper,
						"clipped": clipped,
					}
				)
			)
		if control.clip_contents:
			clip = clip.intersection(box)
			clipped = true
	for child: Node in node.get_children():
		_walk(child, alpha, layer, z, clip, clipped, paper)


func _check_text(text: Dictionary, found: PackedStringArray) -> void:
	var control: Control = text["node"]
	var box: Rect2 = text["whole"]
	if box.size.x < 1.0 or box.size.y < 1.0:
		return
	var said: String = _said(control)
	if not bool(text["clipped"]) and not _screen.grow(SLACK).encloses(box):
		_add(found, "OFFSCREEN", said, "%s leaves the screen %s" % [_at(box), _at(_screen)])
	var cut: String = _cut(control)
	if not cut.is_empty():
		_add(found, "CLIPPED", said, cut)
	var paper: Control = text["paper"]
	if paper != null and not bool(text["clipped"]):
		var sheet: Rect2 = _global(paper, Rect2(Vector2.ZERO, paper.size))
		if not sheet.grow(SLACK).encloses(box):
			_add(found, "OFF-PAPER", said, "%s leaves its paper %s" % [_at(box), _at(sheet)])
	var type: float = _type_size(control)
	if type > 0.0 and type < LEAST_TYPE:
		_add(found, "SMALL", said, "%.1f px type" % type)


## Text drawn over other text: neither holds the other, both in front of the same dims.
func _check_pairs(found: PackedStringArray) -> void:
	for first: int in _texts.size():
		for second: int in range(first + 1, _texts.size()):
			var under: Dictionary = _texts[first]
			var over: Dictionary = _texts[second]
			var a: Control = under["node"]
			var b: Control = over["node"]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			if _level(under["order"]) != _level(over["order"]):
				continue
			# A text on a paper of its own hides what is under that paper: see covered.
			if over["paper"] != under["paper"] and over["paper"] != null:
				if int(over["order"]) > int(under["order"]):
					continue
			if under["paper"] != over["paper"] and under["paper"] != null:
				if int(under["order"]) > int(over["order"]):
					continue
			var under_box: Rect2 = under["box"]
			var over_box: Rect2 = over["box"]
			var shared: Rect2 = under_box.intersection(over_box)
			if shared.size.x < OVERLAP or shared.size.y < OVERLAP:
				continue
			_add(found, "OVERLAP", _said(a), "over %s at %s" % [_said(b), _at(shared)])


## Text partly under a paper that is not its own and is drawn after it.
func _check_covered(found: PackedStringArray) -> void:
	for text: Dictionary in _texts:
		var control: Control = text["node"]
		var box: Rect2 = text["box"]
		var area: float = box.get_area()
		if area < 1.0:
			continue
		for paper: Dictionary in _papers:
			var sheet: Control = paper["node"]
			if int(paper["order"]) < int(text["order"]) or sheet == control:
				continue
			if sheet.is_ancestor_of(control) or control.is_ancestor_of(sheet):
				continue
			if _level(paper["order"]) != _level(text["order"]):
				continue
			if _is_sheet(paper["box"]) or _alike(sheet, text["paper"]):
				continue
			var hidden: float = box.intersection(paper["box"]).get_area() / area
			if hidden > COVERED.x and hidden < COVERED.y:
				var by: String = _name(sheet)
				var share: int = roundi(hidden * 100.0)
				_add(found, "COVERED", _said(control), "%d%% under %s" % [share, by])


## A sheet laid over the page on purpose (the rules, the pause menu, the claim): what it
## covers is behind it, as behind a dim.
func _is_sheet(box: Rect2) -> bool:
	return box.get_area() >= _screen.get_area() * SHEET


## Two papers of one kind side by side, as cards in a fan or a pile, overlap on purpose.
static func _alike(sheet: Control, other: Control) -> bool:
	if other == null or sheet.get_parent() != other.get_parent():
		return false
	return sheet.get_script() == other.get_script() and sheet.get_class() == other.get_class()


## How many full-screen dims are drawn before a piece: pieces are compared within one.
func _level(order: int) -> int:
	var level: int = 0
	for curtain: int in _curtains:
		if curtain < order:
			level += 1
	return level


func _add(found: PackedStringArray, kind: String, said: String, what: String) -> void:
	var key: String = "%s|%s|%s" % [kind, said, what.get_slice(" at ", 0)]
	if _seen.has(key):
		return
	_seen[key] = true
	found.append("%s %s: %s" % [kind, said, what])


static func _has_text(control: Control) -> bool:
	var label: Label = control as Label
	if label != null:
		return not label.text.strip_edges().is_empty()
	var button: Button = control as Button
	if button != null:
		return not button.text.strip_edges().is_empty()
	var rich: RichTextLabel = control as RichTextLabel
	return rich != null and not rich.get_parsed_text().strip_edges().is_empty()


## A sheet with a ground of its own, which hides what is under it.
static func _is_paper(control: Control) -> bool:
	if not (control is PanelContainer or control is Panel):
		return false
	var style: StyleBox = control.get_theme_stylebox("panel")
	return style != null and not style is StyleBoxEmpty


static func _is_curtain(control: Control, box: Rect2) -> bool:
	var rect: ColorRect = control as ColorRect
	if rect == null or rect.color.a < 0.2:
		return false
	var screen: Rect2 = Rect2(Vector2.ZERO, control.get_viewport_rect().size)
	return box.intersection(screen).get_area() >= screen.get_area() * CURTAIN


## Where a text's ink lies on the screen, as near as its font and alignment tell.
static func _text_box(control: Control) -> Rect2:
	var label: Label = control as Label
	if label == null:
		var rich: RichTextLabel = control as RichTextLabel
		var tall: float = control.size.y
		if rich != null:
			tall = minf(tall, float(rich.get_content_height()))
		return _global(control, Rect2(Vector2.ZERO, Vector2(control.size.x, tall)))
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var wide: float = -1.0 if label.autowrap_mode == TextServer.AUTOWRAP_OFF else label.size.x
	var block: Vector2 = font.get_multiline_string_size(
		label.text, HORIZONTAL_ALIGNMENT_LEFT, wide, font_size
	)
	block = Vector2(minf(block.x, label.size.x), minf(block.y, label.size.y))
	var at: Vector2 = Vector2.ZERO
	if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		at.x = (label.size.x - block.x) / 2.0
	elif label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		at.x = label.size.x - block.x
	if label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
		at.y = (label.size.y - block.y) / 2.0
	elif label.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:
		at.y = label.size.y - block.y
	return _global(control, Rect2(at, block))


## Why a text is cut off by its own box, or empty when it is whole.
static func _cut(control: Control) -> String:
	var label: Label = control as Label
	if label != null:
		var lines: int = label.get_line_count()
		var shown: int = label.get_visible_line_count()
		if shown < lines:
			return "shows %d of %d lines" % [shown, lines]
		if label.autowrap_mode == TextServer.AUTOWRAP_OFF and label.clip_text:
			var font: Font = label.get_theme_font("font")
			var needs: float = (
				font
				. get_string_size(
					label.text,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					label.get_theme_font_size("font_size")
				)
				. x
			)
			if needs > label.size.x + SLACK:
				return "needs %d px, has %d" % [roundi(needs), roundi(label.size.x)]
		return ""
	var rich: RichTextLabel = control as RichTextLabel
	if rich != null and not rich.scroll_active and not rich.fit_content:
		var tall: int = rich.get_content_height()
		if tall > rich.size.y + SLACK:
			return "needs %d px of height, has %d" % [tall, roundi(rich.size.y)]
	var button: Button = control as Button
	if button != null and button.clip_text:
		var face: Font = button.get_theme_font("font")
		var wants: float = (
			face
			. get_string_size(
				button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")
			)
			. x
		)
		if wants > button.size.x + SLACK:
			return "needs %d px, has %d" % [roundi(wants), roundi(button.size.x)]
	return ""


## The type's size as drawn, its scale counted, or 0 for a text with no one size.
static func _type_size(control: Control) -> float:
	var size_name: String = "font_size"
	if control is RichTextLabel:
		size_name = "normal_font_size"
	var scale: Vector2 = control.get_global_transform().get_scale()
	return control.get_theme_font_size(size_name) * minf(scale.x, scale.y)


static func _global(control: Control, rect: Rect2) -> Rect2:
	return control.get_global_transform() * rect


static func _said(control: Control) -> String:
	var text: String = ""
	if control is RichTextLabel:
		text = (control as RichTextLabel).get_parsed_text()
	else:
		text = str(control.get("text"))
	text = text.strip_edges().replace("\n", " / ")
	if text.length() > SNIPPET:
		text = text.left(SNIPPET) + "..."
	return '"%s"' % text


## A piece by its script, or its class, with the first words on it.
static func _name(control: Control) -> String:
	var script: Script = control.get_script()
	var kind: String = control.get_class()
	if script != null:
		kind = script.resource_path.get_file().get_basename()
	for child: Node in control.find_children("*", "Label", true, false):
		var label: Label = child as Label
		if not label.text.strip_edges().is_empty():
			return "%s %s" % [kind, _said(label)]
	return kind


static func _at(rect: Rect2) -> String:
	return (
		"[%d,%d %dx%d]"
		% [
			roundi(rect.position.x),
			roundi(rect.position.y),
			roundi(rect.size.x),
			roundi(rect.size.y)
		]
	)
