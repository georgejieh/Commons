class_name SessionNotice
extends Control
## A notice about the game's own session (ADR 0037), over everything: that another copy
## is already open, that the last session did not close and where its files were copied,
## or whether to keep a new window mode (DisplayWindow). A sheet of paper on a dim, with
## its buttons in a row; the first has the focus and the focus stays among them by
## keyboard and gamepad, and the dim stops the mouse short of anything under it.

## Above every screen and the arrival's layer, as the books notice is.
const DRAW_ORDER: int = BooksNotice.DRAW_ORDER
const BODY_SIZE: int = 24
const LINE_SIZE: int = 22

var _eyebrow: String
var _title: String
var _body: String
var _line: String
var _buttons: Array[Button]
var _panel: Control = null
## What Escape or the pad's back button does, if anything.
var _cancel: Callable = Callable()


## line is a smaller line under the body, such as a folder's path, or empty.
func _init(
	eyebrow: String, title: String, body: String, choices: Array[Button], line: String = ""
) -> void:
	_eyebrow = eyebrow
	_title = title
	_body = body
	_buttons = choices
	_line = line


## The notice a second copy shows: Quit, with the focus, and Open anyway.
static func already_open(seconds: int, quit: Callable, anyway: Callable) -> SessionNotice:
	var leave: Button = ScreenKit.button(
		TranslationServer.translate("session.open.quit"), CommonsTheme.PRIMARY
	)
	leave.pressed.connect(quit)
	var go_on: Button = ScreenKit.button(TranslationServer.translate("session.open.anyway"))
	go_on.pressed.connect(anyway)
	var body: String = TranslationServer.translate("session.open.body")
	var wait: String = TranslationServer.translate("session.open.wait").format({"seconds": seconds})
	return SessionNotice.new(
		TranslationServer.translate("session.open.eyebrow"),
		TranslationServer.translate("session.open.title"),
		"%s\n\n%s" % [body, wait],
		[leave, go_on]
	)


## The notice on the title after a session that did not close: OK, with the focus, and a
## button that opens the folder the files were copied to.
static func kept(folder: String) -> SessionNotice:
	var ok: Button = ScreenKit.button(
		TranslationServer.translate("session.kept.ok"), CommonsTheme.PRIMARY
	)
	var open_button: Button = ScreenKit.button(TranslationServer.translate("session.kept.open"))
	var shown: String = ProjectSettings.globalize_path(folder)
	open_button.pressed.connect(func() -> void: OS.shell_open(shown))
	var notice: SessionNotice = SessionNotice.new(
		TranslationServer.translate("session.kept.eyebrow"),
		TranslationServer.translate("session.kept.title"),
		TranslationServer.translate("session.kept.body"),
		[ok, open_button],
		shown
	)
	ok.pressed.connect(notice.close)
	return notice


## The question after a new window mode or size: Keep, with the focus, and Go back, which
## Escape and the pad's back button also choose. The old display comes back by itself
## after seconds.
static func display_check(seconds: int, keep: Callable, restore: Callable) -> SessionNotice:
	var keep_button: Button = ScreenKit.button(
		TranslationServer.translate("display.check.keep"), CommonsTheme.PRIMARY
	)
	keep_button.pressed.connect(keep)
	var back: Button = ScreenKit.button(TranslationServer.translate("display.check.back"))
	back.pressed.connect(restore)
	var body: String = TranslationServer.translate("display.check.body")
	var notice: SessionNotice = SessionNotice.new(
		TranslationServer.translate("display.check.eyebrow"),
		TranslationServer.translate("display.check.title"),
		body.format({"seconds": seconds}),
		[keep_button, back]
	)
	notice._cancel = restore
	return notice


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = DRAW_ORDER
	var dim: ColorRect = ColorRect.new()
	dim.color = BooksNotice.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var paper: VBoxContainer = ScreenKit.card(Vector2(BooksNotice.WIDTH, 0))
	paper.add_theme_constant_override("separation", 14)
	paper.add_child(ScreenKit.eyebrow(_eyebrow.to_upper()))
	paper.add_child(ScreenKit.styled(_title, CommonsTheme.HEADLINE))
	paper.add_child(ScreenKit.label(_body, BODY_SIZE, ScreenKit.INK))
	if not _line.is_empty():
		var line: Label = ScreenKit.label(_line, LINE_SIZE, ScreenKit.INK)
		# A path has no spaces to break at.
		line.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		paper.add_child(line)
	var controls: Array[Control] = []
	controls.assign(_buttons)
	paper.add_child(ScreenKit.row(controls))
	SheetPad.column(paper)
	_panel = ScreenKit.card_panel(paper)
	center.add_child(_panel)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	_buttons[0].grab_focus.call_deferred()


## Takes the notice away, and leaves the focus to what is under it.
func close() -> void:
	get_viewport().gui_focus_changed.disconnect(_on_focus_changed)
	queue_free()


func buttons() -> Array[Button]:
	return _buttons


## The paper the notice is printed on, for layout tests.
func sheet() -> Control:
	return _panel


## Escape goes to the notice before any screen or menu under it can take it.
func _input(event: InputEvent) -> void:
	if _cancel.is_valid() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel.call()


## Focus that leaves the notice's buttons, for a screen under it, comes back.
func _on_focus_changed(control: Control) -> void:
	if is_inside_tree() and not _buttons.has(control):
		_buttons[0].grab_focus.call_deferred()
