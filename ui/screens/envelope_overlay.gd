class_name EnvelopeOverlay
extends Control
## An envelope opened over the shop page (ADR 0021). A Scrim dims the page and takes its
## clicks, the envelope comes to the middle and is opened in one beat, and its papers
## slide out into a row (EnvelopeOpening); a click or an accept ends that act at once. A
## paper is kept by clicking it. Under the row, EnvelopeDetail
## explains the pointed paper where papers do not print their own rules, then one Take
## Nothing. Keeping a paper lifts it
## under a seal, Kept, or Issued with each Rate ticking for a Directive, while the others
## fall away; taking nothing lets them all fall. Then the overlay closes and frees
## everything it made. Reduced motion skips to each end. A card for the deck is kept
## through the deck sheet, which asks for the card it replaces (EnvelopeExchange, ADR
## 0042); backing out of it leaves the envelope as it was.
##
## Keyboard and gamepad: focus lands on the first paper that can be kept, left and right
## move, accept keeps. Cancel never throws an envelope away at once: it moves focus to
## Take Nothing, whose words then ask for a second cancel, which confirms it.

## The envelope is answered and the overlay is gone.
signal closed

const GAP: int = 20
const ROW_GAP: int = 10
## Inside the heading paper's printed border, which ends 17 px in.
const HEADING_PADDING: int = 22
## Seconds: the kept paper's lift, the seal's hold, the gap between one Rate's tick and
## the next, and the overlay's fade as it closes.
const KEEP_TIME: float = 0.2
const SEAL_HOLD: float = 0.9
const TICK_STAGGER: float = 0.12
const CLOSE_TIME: float = 0.22
## How far the kept paper rises and how much it grows.
const KEEP_RISE: float = 26.0
const KEEP_SCALE: float = 1.06
## The seal's width as a share of the kept item's, and how much of it overhangs the
## item's right edge; it sits on the item's foot, above the caption under it.
const SEAL_SHARE: float = 0.62
const SEAL_OVERHANG: float = 0.5
## The instruction under the envelope's name.
const ASK_SIZE: int = 18
## Kept clear between the column and the screen's top and bottom.
const EDGE: float = 16.0

var _controller: RunController
var _shelf: EnvelopeShelf
var _dim: Scrim = Scrim.new()
var _figure: EnvelopeFigure = EnvelopeFigure.new()
var _column: VBoxContainer = VBoxContainer.new()
var _row: HBoxContainer = HBoxContainer.new()
var _papers: Array[ChoicePaper] = []
var _detail: EnvelopeDetail = EnvelopeDetail.new()
var _nothing: Button = ScreenKit.button("", CommonsTheme.GHOST)
## True once a cancel has asked for a second, which Take Nothing's words say.
var _confirming: bool = false
var _pointed_title: String = ""
## The instruction under the envelope's name, and the one reason none of its papers can
## be kept when they all share it, said there once.
var _ask: Label = ScreenKit.label("", ASK_SIZE)
var _refused: String = ""
var _seal: InkSeal = InkSeal.new()
var _opening: EnvelopeOpening = EnvelopeOpening.new()
var _busy: bool = true
var _blocks: Dictionary[String, Control] = {}
## Keeps a card for the deck through the page's deck sheet.
var _exchange: EnvelopeExchange


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 4


## Opens shelf's envelope over the page, from where its offer stood. Without animate, or
## under reduced motion, the papers are laid out at once, as after a load. A card for the
## deck is kept through sheet, which stands over the envelope.
func open(
	controller: RunController, shelf: EnvelopeShelf, from: Rect2, animate: bool, sheet: DeckSheet
) -> void:
	_controller = controller
	_shelf = shelf
	var refocus: Callable = func(index: int) -> void: _papers[index].keep.grab_focus()
	_exchange = EnvelopeExchange.new(sheet, _act_out, refocus)
	add_child(_dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = EDGE
	center.offset_bottom = -EDGE
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_column.add_theme_constant_override("separation", ROW_GAP)
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(_column)
	_column.add_child(_heading())
	_row.add_theme_constant_override("separation", GAP)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_child(_row)
	_fill_row()
	# Always in the tree, so it is freed with the overlay; hidden, it takes no room.
	_column.add_child(_detail)
	_detail.visible = EnvelopeDetail.needed(_shelf)
	if _detail.visible:
		_blocks["detail"] = _detail
	_nothing.text = tr("envelope.nothing")
	_nothing.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_nothing.pressed.connect(_take_nothing)
	_nothing.focus_entered.connect(_point.bind(-1))
	_column.add_child(_nothing)
	_blocks["row"] = _row
	_blocks["button"] = _nothing
	_figure.wrapping = shelf.wrapping(shelf.opened_id())
	_figure.visible = false
	add_child(_figure)
	_seal.z_index = 1
	add_child(_seal)
	_wire_focus()
	if animate and not UiMotion.reduced():
		_opening.play(self, _dim, _figure, _column, _papers, from, _settle)
	else:
		_settle()


## The papers in order, for tests and playtests.
func papers() -> Array[ChoicePaper]:
	return _papers.duplicate()


func nothing_button() -> Button:
	return _nothing


## True while the opening, a keeping or a falling away is acted out.
func is_busy() -> bool:
	return _busy


## The instruction under the envelope's name, for tests.
func asked() -> String:
	return _ask.text


## Take Nothing asks for a second cancel, as it does after the first.
func asks_to_confirm() -> bool:
	return _confirming


func seal() -> InkSeal:
	return _seal


func figure() -> EnvelopeFigure:
	return _figure


## The pointed paper's name, which the explanation under the row shows when there is one.
func shown_title() -> String:
	return _pointed_title


## The overlay's main pieces by name, which must fit the screen without overlapping.
func blocks() -> Dictionary[String, Control]:
	return _blocks.duplicate()


func _heading() -> Control:
	var sheet: PanelContainer = PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", ScreenKit.paper_style(HEADING_PADDING))
	sheet.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var lines: VBoxContainer = VBoxContainer.new()
	lines.add_theme_constant_override("separation", 0)
	lines.add_child(ScreenKit.eyebrow(tr("envelope.eyebrow")))
	var name: Label = ScreenKit.styled(_shelf.envelope_name(_shelf.opened_id()), CommonsTheme.TITLE)
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	lines.add_child(name)
	_refused = EnvelopeDetail.shared_refusal(_shelf)
	_ask.text = tr("envelope.choose")
	if not _refused.is_empty():
		_ask.text = tr("envelope.refused.all").format({"why": tr(_refused)})
	_ask.autowrap_mode = TextServer.AUTOWRAP_OFF
	lines.add_child(_ask)
	sheet.add_child(lines)
	_blocks["heading"] = sheet
	return sheet


## One paper per item, each in a place of its own so it can move while the row holds.
func _fill_row() -> void:
	var item: Vector2 = ChoicePaper.item_for(_shelf.count())
	var strips: bool = ChoicePaper.needs_strips(_shelf)
	for index: int in _shelf.count():
		var place: Control = Control.new()
		place.custom_minimum_size = ChoicePaper.size_for(item, strips)
		place.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_row.add_child(place)
		var paper: ChoicePaper = ChoicePaper.new()
		paper.setup(index, item, strips)
		# In the tree first: a card view is only ready to show a card once it is in it.
		place.add_child(paper)
		var kind: int = _shelf.kind(index)
		if kind == EnvelopeShelf.KIND_DIRECTIVE:
			paper.show_directive(_controller, _shelf.item_id(index))
		elif kind == EnvelopeShelf.KIND_CAMPAIGN:
			paper.show_campaign(_controller, _shelf.item_id(index))
		else:
			paper.show_card(_controller, kind, _shelf.card(index))
		# A reason every paper shares is said once, over the row; each paper says only no.
		var why: String = _shelf.refusal_key(index)
		if not why.is_empty() and not _refused.is_empty():
			why = "envelope.refused.short"
		paper.set_takeable(why.is_empty(), "" if why.is_empty() else tr(why))
		paper.pointed.connect(_point)
		paper.kept.connect(_keep)
		_papers.append(paper)


## Left and right move along the papers, down goes to Take Nothing and up comes back;
## nothing leads out of the overlay.
func _wire_focus() -> void:
	var keeps: Array[Button] = []
	for paper: ChoicePaper in _papers:
		keeps.append(paper.keep)
	for index: int in keeps.size():
		var keep: Button = keeps[index]
		var left: Button = keeps[maxi(index - 1, 0)]
		var right: Button = keeps[mini(index + 1, keeps.size() - 1)]
		keep.focus_neighbor_left = keep.get_path_to(left)
		keep.focus_neighbor_right = keep.get_path_to(right)
		keep.focus_neighbor_top = keep.get_path_to(keep)
		keep.focus_neighbor_bottom = keep.get_path_to(_nothing)
		keep.focus_previous = keep.get_path_to(left)
		keep.focus_next = keep.get_path_to(right if index + 1 < keeps.size() else _nothing)
	var back: Button = _nothing if keeps.is_empty() else keeps[0]
	for neighbour: String in ["focus_neighbor_left", "focus_neighbor_right"]:
		_nothing.set(neighbour, _nothing.get_path_to(_nothing))
	_nothing.focus_neighbor_bottom = _nothing.get_path_to(_nothing)
	_nothing.focus_neighbor_top = _nothing.get_path_to(back)
	_nothing.focus_next = _nothing.get_path_to(back)
	_nothing.focus_previous = _nothing.get_path_to(keeps[-1] if not keeps.is_empty() else back)


## Everything at rest and ready to choose.
func _settle() -> void:
	_figure.visible = false
	_dim.modulate.a = 1.0
	_column.modulate.a = 1.0
	for paper: ChoicePaper in _papers:
		paper.position = Vector2.ZERO
		paper.scale = Vector2.ONE
		paper.rotation = 0.0
	_busy = false
	for paper: ChoicePaper in _papers:
		if paper.is_takeable():
			paper.keep.grab_focus()
			return
	# None can be kept: the first is explained all the same, so the paper under the row
	# is never blank. Focus then goes to Take Nothing, which leaves that text standing.
	if not _papers.is_empty():
		_point(0)
	_nothing.grab_focus()


## Shows the pointed paper's name and rules, with why it cannot be kept when it cannot.
func _point(index: int) -> void:
	for paper: ChoicePaper in _papers:
		paper.set_cursor(paper.index == index)
	if index < 0:
		return
	_ask_confirm(false)
	var paper: ChoicePaper = _papers[index]
	_pointed_title = paper.title
	var rule: String = paper.rule
	if not paper.is_takeable() and _refused.is_empty():
		rule += "\n\n" + paper.caption()
	_detail.explain(paper.title, rule)


func _input(event: InputEvent) -> void:
	if _opening.is_playing():
		# The act is ended, and the input with it: a second one chooses.
		if EnvelopeOpening.ends(event):
			get_viewport().set_input_as_handled()
			_opening.stop()
			_settle()
		return
	if not event.is_action_pressed("ui_cancel") or _exchange.is_open():
		return
	get_viewport().set_input_as_handled()
	if _busy:
		return
	if _nothing.has_focus() and asks_to_confirm():
		_take_nothing()
		return
	_nothing.grab_focus()
	_ask_confirm(true)


func _ask_confirm(on: bool) -> void:
	_confirming = on
	_nothing.text = tr("envelope.nothing.confirm" if on else "envelope.nothing")


## Keeps the paper: the pick is sent now, or once the deck sheet has named the card a deck
## card replaces, then acted out.
func _keep(index: int) -> void:
	if _busy or not _papers[index].is_takeable() or _exchange.is_open():
		return
	if _shelf.is_deck_card(index):
		_exchange.ask(_controller, _shelf, index)
		return
	var directive: bool = _shelf.kind(index) == EnvelopeShelf.KIND_DIRECTIVE
	var issued: String = _shelf.item_id(index) if directive else ""
	var before: Array[int] = []
	if directive:
		before = DirectiveSheet.rates(_controller, issued)
	if _controller.envelope_pick(index) == RunController.OK:
		_act_out(index, issued, before)


## The kept paper lifts under its seal while the others fall, then the overlay closes. An
## issued Directive's Rates tick up from before.
func _act_out(index: int, issued: String = "", before: Array[int] = []) -> void:
	var paper: ChoicePaper = _papers[index]
	var directive: bool = not issued.is_empty()
	Audio.play(AudioEvents.STORE_BUY)
	if UiMotion.reduced():
		_finish()
		return
	_busy = true
	var others: Array[ChoicePaper] = _papers.filter(
		func(other: ChoicePaper) -> bool: return other != paper
	)
	EnvelopeOpening.fall(others)
	# Once a paper is kept, Take Nothing is done with: it fades from under the seal.
	_nothing.disabled = true
	_nothing.create_tween().tween_property(_nothing, "modulate:a", 0.0, KEEP_TIME)
	paper.z_index = 1
	var word: String = tr("directive.issued" if directive else "envelope.kept")
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(paper, "position:y", -KEEP_RISE, KEEP_TIME)
	tween.parallel().tween_property(paper, "scale", Vector2.ONE * KEEP_SCALE, KEEP_TIME)
	tween.tween_callback(_press_seal.bind(paper, word))
	if directive:
		DirectiveSheet.tick(tween, _controller, issued, paper.lines, before, TICK_STAGGER)
		tween.tween_interval(UiMotion.PRESETS.count_time)
	tween.tween_interval(SEAL_HOLD)
	tween.tween_property(self, "modulate:a", 0.0, CLOSE_TIME)
	tween.tween_callback(_finish)


## Where a control is drawn on screen, its scale counted, which get_global_rect leaves out.
static func shown_rect(control: Control) -> Rect2:
	var shown: Transform2D = control.get_global_transform()
	return Rect2(shown.origin, control.size * shown.get_scale())


## The seal lands on the kept item's foot at its right edge, half of it off the paper,
## so the name, the mark and the caption under the item stay in sight.
func _press_seal(paper: ChoicePaper, word: String) -> void:
	var shown: Rect2 = shown_rect(paper.item)
	var wide: float = shown.size.x * SEAL_SHARE
	_seal.prepare(word, ScreenKit.RED, wide)
	var middle: Vector2 = shown.end - Vector2(wide * (0.5 - SEAL_OVERHANG), wide * 0.5)
	_seal.position = middle - global_position - _seal.size / 2.0
	_seal.press()


## Takes nothing: every paper falls away, then the overlay closes.
func _take_nothing() -> void:
	if _busy:
		return
	if _controller.envelope_pick(RunController.TAKE_NOTHING) != RunController.OK:
		return
	if UiMotion.reduced():
		_finish()
		return
	_busy = true
	EnvelopeOpening.fall(_papers)
	var tween: Tween = create_tween()
	tween.tween_interval(EnvelopeOpening.FALL_TIME + EnvelopeOpening.FAN_STAGGER * _papers.size())
	tween.tween_property(self, "modulate:a", 0.0, CLOSE_TIME)
	tween.tween_callback(_finish)


func _finish() -> void:
	_busy = true
	closed.emit()
	queue_free()
