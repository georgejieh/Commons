extends RefCounted
## Looks over everything on screen for layout faults a person would see, so the
## playtest's walk finds them on every screen it visits and not only where a layout test
## was written: text cut off by its box, a piece of text or a panel partly off the screen,
## text that runs out of the paper it is on, text drawn over other text, text partly under
## another paper, and type under the least the game sets any text at. It reads the tree
## and never changes it. What is by design is left out, each known by what it is: what is
## behind a dim over the page (a dialog, the deck sheet or an open envelope), or under a
## large sheet; cards of one fan over one another; a slip over the row of the piece it
## explains, or of the paper of the word it was opened from; a shout's banner, which takes
## the screen for its moment; what a ScrollContainer cuts off, which is scrolled; and a
## piece in flight, which moved, turned or swelled between look() and check().
## A finding is meant to be a fault. Each is reported once a run.
## Loaded at run time by playtest.gd; it names no ui/ class. Development only.

## Two texts overlap when their boxes share at least this much, each way.
const OVERLAP: float = 6.0
## A paper covers a text when it hides between these shares of it: less is a touch, and
## all of it is a text put away on purpose.
const COVERED: Vector2 = Vector2(0.12, 0.92)
## The least size the game sets text the player reads at, from the data TextSize reads.
const LEAST_TYPE: int = SettingsStore.DEFAULTS.least_text_px
## A piece this faint is still arriving or is put away.
const FAINT: float = 0.35
## A full-screen piece covers at least this share of the screen.
const CURTAIN: float = 0.95
## A paper this share of the screen or more is a sheet laid over the page on purpose.
const SHEET: float = 0.12
const SNIPPET: int = 28

var _seen: Dictionary[String, bool] = {}
## Where each piece stood at look(), by instance id; empty when look() was not called.
var _rest: Dictionary[int, Transform2D] = {}
var _screen: Rect2
## One entry per text and per paper, in the order they are drawn.
var _texts: Array[Dictionary] = []
var _papers: Array[Dictionary] = []
var _curtains: Array[int] = []
var _count: int = 0


## Notes where every piece stands now, so check() can leave out what moved since.
func look(root: Window) -> void:
	_rest.clear()
	for node: Node in root.find_children("*", "Control", true, false):
		var control: Control = node as Control
		_rest[control.get_instance_id()] = control.get_global_transform()


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
	if control != null and _in_flight(control):
		return
	if control != null:
		# Draw order as one number: the canvas layer first, then z (raised by 4096, the
		# engine's lowest z, to stay positive), then tree order, each in a band wide
		# enough for the one under it.
		var order: int = layer * 100000000 + (z + 4096) * 10000 + _count
		var box: Rect2 = LayoutMeasure.global_rect(control, Rect2(Vector2.ZERO, control.size))
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
						"box": LayoutMeasure.text_box(control).intersection(clip),
						"whole": LayoutMeasure.text_box(control),
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
	if not bool(text["clipped"]) and not _screen.grow(LayoutMeasure.SLACK).encloses(box):
		_add(found, "OFFSCREEN", said, "%s leaves the screen %s" % [_at(box), _at(_screen)])
	var cut: String = LayoutMeasure.cut(control)
	if not cut.is_empty():
		_add(found, "CLIPPED", said, cut)
	var paper: Control = text["paper"]
	if paper != null and not bool(text["clipped"]):
		var sheet: Rect2 = LayoutMeasure.global_rect(paper, Rect2(Vector2.ZERO, paper.size))
		if not sheet.grow(LayoutMeasure.SLACK).encloses(box):
			_add(found, "OFF-PAPER", said, "%s leaves its paper %s" % [_at(box), _at(sheet)])
	var type: float = LayoutMeasure.type_size(control)
	if type > 0.0 and type < float(LEAST_TYPE):
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
			if _shouted(a) or _shouted(b):
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
			if _follows_row(sheet, control) or _over_its_word(sheet, control):
				continue
			if _one_fan(sheet, control):
				continue
			var hidden: float = box.intersection(paper["box"]).get_area() / area
			if hidden > COVERED.x and hidden < COVERED.y:
				var by: String = _name(sheet)
				var share: int = roundi(hidden * 100.0)
				_add(found, "COVERED", _said(control), "%d%% under %s" % [share, by])


## True when a piece stands elsewhere than at look(), or was not there: it is still
## moving, turning or swelling, and is judged once it comes to rest.
func _in_flight(control: Control) -> bool:
	if _rest.is_empty():
		return false
	var id: int = control.get_instance_id()
	if not _rest.has(id):
		return true
	var was: Transform2D = _rest[id]
	return not was.is_equal_approx(control.get_global_transform())


## A sheet laid over the page on purpose (the rules, the pause menu, the claim): what it
## covers is behind it, as behind a dim.
func _is_sheet(box: Rect2) -> bool:
	return box.get_area() >= _screen.get_area() * SHEET


## A slip that explains a piece, and says which through anchor(), stands beside it and
## may lie over the row the piece stands in: the cards beside the one it explains.
static func _follows_row(sheet: Control, control: Control) -> bool:
	if not sheet.has_method("anchor"):
		return false
	var found: Variant = sheet.call("anchor")
	if not found is Control:
		return false
	var piece: Control = found
	var row: Node = piece.get_parent()
	return row != null and row.is_ancestor_of(control)


## A slip opened from a word, which names that text as its source, stands by the word and,
## as a slip that explains a piece does, may lie over the row of the paper the word is
## printed on: a card's name over its rules, the cards beside it, or the slip it was
## opened from. A paper as large as a sheet is not one word's paper, and there the slip
## may lie over the word's own row alone.
func _over_its_word(sheet: Control, control: Control) -> bool:
	var found: Variant = sheet.get("source")
	if not found is Control:
		return false
	var source: Control = found
	var paper: Node = source
	while paper != null and not (paper is Control and _is_paper(paper as Control)):
		paper = paper.get_parent()
	var piece: Node = source
	if paper != null and not _is_sheet((paper as Control).get_global_rect()):
		piece = paper
	var row: Node = piece.get_parent()
	return row != null and (row == control or row.is_ancestor_of(control))


## A shout, which says what it is by shout(), takes the whole screen for its moment, about a
## second while the table stands still, and hands it back: its words lie over the table on
## purpose, and nothing under them is read until it is gone.
static func _shouted(control: Control) -> bool:
	var node: Node = control
	while node != null:
		if node.has_method("shout"):
			return true
		node = node.get_parent()
	return false


## Cards of one fan overlap on purpose: below the nearest node the paper and the text
## share, they lie in two pieces of one kind, made by one script, as two cards are.
static func _one_fan(sheet: Control, control: Control) -> bool:
	var holder: Node = sheet
	while holder.get_parent() != null and not holder.get_parent().is_ancestor_of(control):
		holder = holder.get_parent()
	var shared: Node = holder.get_parent()
	if shared == null:
		return false
	var other: Node = control
	while other.get_parent() != shared:
		other = other.get_parent()
	return holder.get_script() != null and holder.get_script() == other.get_script()


## Two papers of one kind, as cards in a fan or in the plays of a pile, overlap on purpose.
static func _alike(sheet: Control, other: Control) -> bool:
	if other == null:
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


## A dim over the page: a ColorRect dark enough to see by that covers the canvas the game
## lays its pages out on. The canvas, not the window: a window taller than the canvas
## (a headless run's is square) leaves a band no page fills, and a sheet that dims the
## canvas, as the deck sheet does, is a dim all the same.
static func _is_curtain(control: Control, box: Rect2) -> bool:
	var rect: ColorRect = control as ColorRect
	if rect == null or rect.color.a < 0.2:
		return false
	var canvas: Rect2 = Rect2(Vector2.ZERO, _canvas_size())
	return box.intersection(canvas).get_area() >= canvas.get_area() * CURTAIN


## The size of the canvas the game lays its pages out on, from the project's settings.
static func _canvas_size() -> Vector2:
	return Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)


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
