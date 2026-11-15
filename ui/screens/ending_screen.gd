class_name EndingScreen
extends Control
## How a run ended (ADR 0024), on one aged sheet over the village at night. The ending's
## title is the largest thing on the page, in its framed title card, where the ending's
## picture will hang once it has one; then the ending's text, the two meters and the
## final class. Beside them each family's epilogue line arrives a beat after the last,
## and any accept press shows the rest at once. The Secret Contract and The Commons close
## on the historical note. A run that died shows the record of its death and no epilogue.

const MARGIN: Vector2 = Vector2(56, 36)
const FRAME_HEIGHT: float = 340.0
## The title's largest and smallest size: it shrinks to fit its card on one line.
const TITLE_MAX: int = 84
const TITLE_MIN: int = 48
const TEXT_SIZE: int = 22
const NOTE_SIZE: int = 16
const SEAL_WIDTH: float = 92.0
## The text column's width on a death's page, which has no epilogue beside it.
const DEATH_WIDTH: float = 1180.0
const TITLE_INK: Color = Color("9a2a1a")

var _view: EndingView
var _title: Label
var _heading: HBoxContainer
var _list: EpilogueList = null
var _show_all: Button = null
var _home: Button


func open(app: DemoApp) -> void:
	_view = app.controller.ending()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ScreenKit.cover(ScreenKit.ART.title_night))
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.05, 0.03, 0.02, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, int(MARGIN.x))
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(MARGIN.y))
	add_child(margin)
	var paper: EndingPaper = EndingPaper.new()
	margin.add_child(paper)
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	paper.add_child(page)
	var columns: HBoxContainer = ScreenKit.row([], 48)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(columns)
	var story: VBoxContainer = _story()
	columns.add_child(story)
	if _view.death:
		story.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		story.custom_minimum_size.x = DEATH_WIDTH
		columns.alignment = BoxContainer.ALIGNMENT_CENTER
	else:
		columns.add_child(_village())
	page.add_child(_buttons(app))
	ScreenKit.reveal(page)
	# The title lands like a verdict, in ink.
	UiMotion.stamp(_heading)
	_start()


## The ending itself: the title card, the text, then the meters and class as tiles.
func _story() -> VBoxContainer:
	var story: VBoxContainer = VBoxContainer.new()
	story.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story.size_flags_stretch_ratio = 1.15
	story.add_theme_constant_override("separation", 18)
	story.add_child(ScreenKit.eyebrow(tr("end.eyebrow")))
	story.add_child(_title_card())
	var text: Label = ScreenKit.label(_view.text, TEXT_SIZE, ScreenKit.INK)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story.add_child(text)
	var tiles: Array[Control] = [
		ScreenKit.stat(tr("end.famine"), _view.famine),
		ScreenKit.stat(tr("end.denunciation"), _view.denunciation),
		_class_tile(),
	]
	story.add_child(ScreenKit.row(tiles, 20))
	return story


## The framed card at the top of the page: the ending's picture once it has one, with
## the title under it, or until then the title set in type inside the printed frame.
func _title_card() -> Control:
	var card: VBoxContainer = VBoxContainer.new()
	var frame: Control = Control.new()
	frame.custom_minimum_size = Vector2(0, FRAME_HEIGHT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(frame)
	var printed: ArtFrame = ArtFrame.new()
	printed.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(printed)
	_title = ScreenKit.label(_view.title, TITLE_MAX, TITLE_INK)
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
	var heading: HBoxContainer = ScreenKit.row([_title], 28)
	_heading = heading
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	if HanziSeal.can_draw(_view.seal):
		heading.add_child(HanziSeal.new(_view.seal, SEAL_WIDTH))
	var picture: Texture2D = ScreenKit.ending_art(_view.id)
	if picture != null:
		var art: TextureRect = ScreenKit.cover(picture)
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.offset_left = 10
		art.offset_top = 10
		art.offset_right = -10
		art.offset_bottom = -10
		frame.add_child(art)
		card.add_child(heading)
	else:
		var center: CenterContainer = CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(heading)
		frame.add_child(center)
	frame.resized.connect(_fit_title.bind(frame))
	return card


## The title keeps to one line: it shrinks from its largest size until it fits its card,
## beside the seal when there is one.
func _fit_title(frame: Control) -> void:
	var room: float = frame.size.x - 80.0
	if HanziSeal.can_draw(_view.seal):
		room -= SEAL_WIDTH + 28.0
	var font: Font = ScreenKit.DISPLAY_BOLD
	var font_size: int = TITLE_MAX
	while font_size > TITLE_MIN and _width(font, font_size) > room:
		font_size -= 2
	_title.add_theme_font_size_override("font_size", font_size)


func _width(font: Font, font_size: int) -> float:
	return font.get_string_size(_view.title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _class_tile() -> Control:
	var tile: VBoxContainer = ScreenKit.card(Vector2(240, 0))
	tile.add_child(ScreenKit.eyebrow(tr("end.class")))
	var key: String = "end.class.landlord" if _view.landlord else "end.class.peasant"
	tile.add_child(ScreenKit.styled(tr(key), CommonsTheme.TITLE))
	return ScreenKit.card_panel(tile)


## The village's column: each family's line, then the historical note where it belongs.
func _village() -> VBoxContainer:
	var village: VBoxContainer = VBoxContainer.new()
	village.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	village.add_theme_constant_override("separation", 14)
	village.add_child(ScreenKit.eyebrow(tr("end.village")))
	_list = EpilogueList.new()
	_list.set_lines(_view.lines)
	village.add_child(_list)
	if not _view.note.is_empty():
		var note: Label = ScreenKit.label(_view.note, NOTE_SIZE, ScreenKit.INK)
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		village.add_child(note)
	return village


func _buttons(app: DemoApp) -> HBoxContainer:
	var bar: HBoxContainer = ScreenKit.row([], 20)
	bar.alignment = BoxContainer.ALIGNMENT_END
	if _list != null:
		_show_all = ScreenKit.button(tr("end.show_all"), CommonsTheme.SECONDARY)
		_show_all.pressed.connect(skip)
		bar.add_child(_show_all)
	_home = ScreenKit.button(tr("end.to_title"), CommonsTheme.PRIMARY)
	_home.pressed.connect(func() -> void: app.show_screen("title", true))
	bar.add_child(_home)
	return bar


## Starts the epilogue's lines, or goes straight to the way home when there are none.
func _start() -> void:
	if _list == null:
		_home.grab_focus.call_deferred()
		return
	_list.revealed.connect(_on_revealed)
	_list.reveal(UiMotion.PRESETS.epilogue_beat)
	if _list.is_revealing():
		_show_all.grab_focus.call_deferred()


## Shows every epilogue line at once.
func skip() -> void:
	if _list != null and _list.is_revealing():
		_list.show_all()


func is_revealing() -> bool:
	return _list != null and _list.is_revealing()


func _on_revealed() -> void:
	if _show_all != null:
		_show_all.visible = false
	_home.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and is_revealing():
		skip()
		get_viewport().set_input_as_handled()


## What a test or the playtest reads: the epilogue, the way home and Show all.
func epilogue() -> EpilogueList:
	return _list


func home_button() -> Button:
	return _home


func show_all_button() -> Button:
	return _show_all
