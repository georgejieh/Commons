class_name EndingScreen
extends Control
## How a run ended (ADR 0024), on one aged sheet over the village at night. The ending's
## title is the largest thing on the page, in its framed title card, where the ending's
## picture will hang once it has one; then the ending's text, the two meters and the
## final class. Beside them each family's epilogue line arrives a beat after the last,
## and any accept press shows the rest at once. The Secret Contract and The Commons close
## on the historical note. A run that died shows the record of its death and no epilogue.
## The story scrolls when a larger text size makes it too tall (ADR 0034); the figures are
## not prose, so they stand at the foot of the page with the way home, always whole.

const MARGIN: Vector2 = Vector2(56, 36)
## How far the backdrop darkens under the page.
const SHADE: Color = Color(0.05, 0.03, 0.02, 0.5)
const FRAME_HEIGHT: float = 308.0
## The title card's height with a picture hung in it, which leaves the title under the
## frame, and the picture's margin inside its printed frame.
const PICTURE_HEIGHT: float = 288.0
const PICTURE_INSET: float = 10.0
## Where the story is taller than its column, the title card gives up height first, down
## to this, so the text stands whole before anything scrolls.
const FRAME_LEAST: float = 150.0
## The title's largest and smallest size: it shrinks to fit its card on one line.
const TITLE_MAX: int = 84
const TITLE_MIN: int = 48
const TEXT_SIZE: int = 22
## The historical note: small print, but never under the readable floor as drawn.
const NOTE_SIZE: int = 18
const NAME_SIZE: int = 26
const SEAL_WIDTH: float = 92.0
## The text column's width on a death's page, which has no epilogue beside it.
const DEATH_WIDTH: float = 1180.0

var _view: EndingView
## The run's last state, for how its figures show (ADR 0022).
var _state: RunView = null
## The line under the eyebrow naming the player (ADR 0028).
var _name: Label
var _title: Label
var _heading: HBoxContainer
## The title card's frame, the height it stands at when there is room, and the story.
var _frame: Control
var _frame_full: float = 0.0
var _story_column: VBoxContainer
var _list: EpilogueList = null
var _story_scroll: ProseScroll = null
var _show_all: Button = null
var _home: Button
## The two meters and the final class, as tiles at the page's foot.
var _figures: HBoxContainer


func open(app: DemoApp) -> void:
	_view = app.controller.seats.ending()
	_state = app.controller.run
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ScreenKit.cover(ScreenKit.ART.title_night))
	add_child(ScreenKit.shade(SHADE))
	var margin: MarginContainer = ScreenKit.margins(int(MARGIN.x), int(MARGIN.y))
	add_child(margin)
	var paper: EndingPaper = EndingPaper.new()
	margin.add_child(paper)
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	paper.add_child(page)
	var columns: HBoxContainer = ScreenKit.row([], 48)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(columns)
	_story_scroll = _reading()
	columns.add_child(_story_scroll)
	if _view.death:
		columns.alignment = BoxContainer.ALIGNMENT_CENTER
	else:
		columns.add_child(_village())
	page.add_child(_buttons(app))
	ScreenKit.reveal(page)
	# The title lands like a verdict, in ink.
	UiMotion.stamp(_heading)
	_start()


## The story on a scroll of its paper, for when a larger text size makes it taller than
## the page (ADR 0034); the way home stays on screen. A death has no epilogue beside it:
## its column sits in the middle of the sheet, both ways, so the page has no empty half.
func _reading() -> ProseScroll:
	var story: VBoxContainer = _story()
	var reading: Control = story
	if _view.death:
		story.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		story.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		story.custom_minimum_size.x = DEATH_WIDTH
		var middle: CenterContainer = CenterContainer.new()
		middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
		middle.add_child(story)
		reading = middle
	var scroll: ProseScroll = ProseScroll.new(reading)
	ScrollFade.over(scroll)
	scroll.resized.connect(_fit_frame.call_deferred)
	story.minimum_size_changed.connect(_fit_frame.call_deferred)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = (
		Control.SIZE_SHRINK_CENTER if _view.death else Control.SIZE_EXPAND_FILL
	)
	scroll.size_flags_stretch_ratio = story.size_flags_stretch_ratio
	return scroll


## The ending itself: the title card, then the text. The figures go at the page's foot.
func _story() -> VBoxContainer:
	var story: VBoxContainer = VBoxContainer.new()
	story.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story.size_flags_stretch_ratio = 1.15
	story.add_theme_constant_override("separation", 18)
	# The eyebrow and the player's name under it sit tight, as a header's lines do.
	_story_column = story
	var heading: VBoxContainer = VBoxContainer.new()
	heading.add_theme_constant_override("separation", 0)
	var eyebrow: Label = ScreenKit.eyebrow(tr("end.eyebrow"))
	heading.add_child(eyebrow)
	_name = ScreenKit.label(_view.player_name, NAME_SIZE, ScreenKit.INK)
	_name.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
	heading.add_child(_name)
	story.add_child(heading)
	story.add_child(_title_card())
	var text: Label = ScreenKit.label(_view.text, TEXT_SIZE, ScreenKit.INK)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story.add_child(text)
	# A death's column is centred on the sheet, so its lines are centred in it too.
	if _view.death:
		for line: Label in [eyebrow, _name, text]:
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tiles: Array[Control] = [
		ScreenKit.figure_stat(tr("end.famine"), _state, RunCorrections.FAMINE, _view.famine),
		ScreenKit.figure_stat(
			tr("end.denunciation"), _state, RunCorrections.DENUNCIATION, _view.denunciation
		),
		_class_tile(),
	]
	_figures = ScreenKit.row(tiles, 20)
	return story


## The framed card at the top of the page: the ending's picture once it has one, with
## the title under it, or until then the title set in type inside the printed frame.
func _title_card() -> Control:
	var card: VBoxContainer = VBoxContainer.new()
	var frame: Control = Control.new()
	_frame = frame
	frame.custom_minimum_size = Vector2(0, FRAME_HEIGHT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(frame)
	var picture: Texture2D = ScreenKit.ending_art(_view.id)
	var printed: ArtFrame = ArtFrame.new()
	printed.set_anchors_preset(Control.PRESET_FULL_RECT)
	if picture != null:
		frame.custom_minimum_size.y = PICTURE_HEIGHT
		frame.add_child(_hung(picture, printed))
	else:
		frame.add_child(printed)
	_title = ScreenKit.label(_view.title, TITLE_MAX, ScreenKit.ENDING_INK)
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
	var heading: HBoxContainer = ScreenKit.row([_title], 28)
	_heading = heading
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	if HanziSeal.can_draw(_view.seal):
		heading.add_child(HanziSeal.new(_view.seal, SEAL_WIDTH))
	if picture != null:
		card.add_child(heading)
	else:
		var center: CenterContainer = CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(heading)
		frame.add_child(center)
	frame.resized.connect(_fit_title.bind(frame))
	_frame_full = frame.custom_minimum_size.y
	return card


## The title card stands shorter, down to FRAME_LEAST, by as much as the story is taller
## than its column, and back up as room comes back.
func _fit_frame() -> void:
	if _frame == null or _story_scroll == null or _story_scroll.size.y <= 0.0:
		return
	var spare: float = _story_scroll.size.y - _story_column.get_combined_minimum_size().y
	var want: float = clampf(_frame.custom_minimum_size.y + spare, FRAME_LEAST, _frame_full)
	if absf(want - _frame.custom_minimum_size.y) > 0.5:
		_frame.custom_minimum_size.y = floorf(want)


## The ending's picture hung whole in the middle of the title card's space, at its own
## shape, inside the printed frame drawn tight around it: never stretched, never cropped.
func _hung(picture: Texture2D, printed: ArtFrame) -> AspectRatioContainer:
	var hanger: AspectRatioContainer = AspectRatioContainer.new()
	hanger.set_anchors_preset(Control.PRESET_FULL_RECT)
	hanger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hanger.stretch_mode = AspectRatioContainer.STRETCH_FIT
	hanger.ratio = picture.get_width() / maxf(1.0, picture.get_height())
	var print_area: Control = Control.new()
	print_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hanger.add_child(print_area)
	print_area.add_child(printed)
	var art: TextureRect = TextureRect.new()
	art.name = "EndingPicture"
	art.texture = picture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["offset_left", "offset_top"]:
		art.set(side, PICTURE_INSET)
	for side: String in ["offset_right", "offset_bottom"]:
		art.set(side, -PICTURE_INSET)
	print_area.add_child(art)
	return hanger


## The title keeps to one line: it shrinks from its largest size until it fits its card,
## beside the seal when there is one.
func _fit_title(frame: Control) -> void:
	var room: float = frame.size.x - 80.0
	if HanziSeal.can_draw(_view.seal):
		room -= SEAL_WIDTH + 28.0
	var font: Font = ScreenKit.DISPLAY_BOLD
	var font_size: int = NameFit.one_line_size(
		font, _view.title, room, TextSize.px(TITLE_MAX), TextSize.least(TITLE_MIN), 2
	)
	_title.add_theme_font_size_override("font_size", maxi(font_size, TextSize.least(TITLE_MIN)))


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


## The page's foot: the figures at the left, the way home at the right, level with the
## tiles' foot.
func _buttons(app: DemoApp) -> HBoxContainer:
	var bar: HBoxContainer = ScreenKit.row([_figures], 20)
	var room: Control = Control.new()
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(room)
	if _list != null:
		_show_all = ScreenKit.button(tr("end.show_all"), CommonsTheme.SECONDARY)
		_show_all.pressed.connect(skip)
		bar.add_child(_show_all)
	_home = ScreenKit.button(tr("end.to_title"), CommonsTheme.PRIMARY)
	# The run is over: going home clears its save (ADR 0025).
	_home.pressed.connect(app.leave_run)
	bar.add_child(_home)
	for button: Button in [_show_all, _home]:
		if button != null:
			button.size_flags_vertical = Control.SIZE_SHRINK_END
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


## The story's scroll, for tests.
func story_scroll() -> ProseScroll:
	return _story_scroll


## The meters' and class's tiles, for tests.
func figures() -> HBoxContainer:
	return _figures


## The line naming the player, for tests.
func name_label() -> Label:
	return _name


func home_button() -> Button:
	return _home


func show_all_button() -> Button:
	return _show_all
