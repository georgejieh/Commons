class_name SeatPanel
extends PanelContainer
## One villager at the table, on one paper sheet: portrait, name, cards left, role and
## their last words. The sheet grows with its content, so the portrait always sits
## inside it. The card count turns red at 2 and 1 cards. A line types out in step with
## the villager's voice (P3B.13); clicking it shows the rest at once.

## The player skipped the line typing out, so its voice should stop.
signal speech_skipped(seat: int)

const INK: Color = Color("1e1a16")
const LANDLORD_RED: Color = Color("9e1b16")
const GOLD: Color = Color("c9a227")
const PAPER: Color = Color("d9c8a4")
## The portrait's frame, and the picture inside it after the frame's 4 px edge.
const PORTRAIT_BOX: Vector2 = Vector2(110, 138)
const PICTURE_BOX: Vector2 = Vector2(102, 130)

var seat: int = -1

var _banner: Label = Label.new()
var _portrait: ColorRect = ColorRect.new()
var _picture: TextureRect = TextureRect.new()
var _name: Label = Label.new()
var _count: Label = Label.new()
var _role: Label = Label.new()
var _speech: Label = Label.new()
var _info: VBoxContainer = VBoxContainer.new()
var _back: TextureRect = TextureRect.new()
var _count_row: HBoxContainer = HBoxContainer.new()
var _row: HBoxContainer = HBoxContainer.new()
var _mood: String = ""
## When each character of the current line shows, and how long it has been typing.
var _reveal: PackedFloat32Array = PackedFloat32Array()
var _typed: float = 0.0


func _init() -> void:
	theme_type_variation = CommonsTheme.SHEET
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 14)
	add_child(_row)
	_info.add_theme_constant_override("separation", 4)
	_banner.text = tr("table.landlord").to_upper()
	_banner.theme_type_variation = CommonsTheme.EYEBROW
	_banner.add_theme_color_override("font_color", ScreenKit.STYLE.paper_bright)
	var tag: StyleBoxFlat = StyleBoxFlat.new()
	tag.bg_color = ScreenKit.STYLE.vermilion
	tag.set_corner_radius_all(ScreenKit.STYLE.radius)
	tag.content_margin_left = 10
	tag.content_margin_right = 10
	_banner.add_theme_stylebox_override("normal", tag)
	_banner.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_portrait.custom_minimum_size = PORTRAIT_BOX
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_portrait.color = PAPER
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picture.offset_left = 4
	_picture.offset_top = 4
	_picture.offset_right = -4
	_picture.offset_bottom = -4
	_portrait.add_child(_picture)
	_name.theme_type_variation = CommonsTheme.TITLE
	_name.add_theme_font_size_override("font_size", 36)
	_count.add_theme_font_size_override("font_size", 26)
	_count.add_theme_color_override("font_color", INK)
	_role.theme_type_variation = CommonsTheme.EYEBROW
	_speech.add_theme_font_size_override("font_size", 20)
	_speech.add_theme_color_override("font_color", INK)
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.custom_minimum_size = Vector2(200, 0)
	_speech.max_lines_visible = 2
	_speech.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_speech.mouse_filter = Control.MOUSE_FILTER_STOP
	_speech.gui_input.connect(_on_speech_input)
	set_process(false)
	_row.add_child(_portrait)
	_back.texture = ArtStages.resolve(ScreenKit.ART.card_back)
	_back.custom_minimum_size = Vector2(30, 42)
	_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_count_row.add_child(_back)
	_count_row.add_child(_count)
	for child: Control in [_banner, _name, _count_row, _role, _speech]:
		_info.add_child(child)
	_row.add_child(_info)


func setup(seat_index: int, display_name: String, portrait: Texture2D = null) -> void:
	seat = seat_index
	_name.text = display_name
	_picture.texture = portrait


func set_count(cards: int) -> void:
	var key: String = "table.card_left" if cards == 1 else "table.cards_left"
	_count.text = tr(key).format({"count": cards})
	_count.add_theme_color_override("font_color", LANDLORD_RED if cards <= 2 else INK)


func set_role(is_landlord: bool, teammate: bool) -> void:
	# The tag keeps its space either way, so the seat never changes height.
	_banner.modulate.a = 1.0 if is_landlord else 0.0
	_portrait.color = GOLD if is_landlord else PAPER
	if is_landlord:
		_role.text = tr("table.role.landlord").to_upper()
	elif teammate:
		_role.text = tr("table.role.teammate").to_upper()
	else:
		_role.text = tr("table.role.peasant").to_upper()


## Shows a line; mood is the line's mood tag. With reveal times from the voice plan
## (P3B.13) it types out, one character at each time; without, it shows at once.
func say(
	text: String, mood: String = "", reveal: PackedFloat32Array = PackedFloat32Array()
) -> void:
	_speech.text = text
	_mood = mood
	_reveal = reveal
	_typed = 0.0
	_speech.visible_characters = -1 if reveal.is_empty() else 0
	set_process(not reveal.is_empty())


## Shows the rest of a line still typing out. True if one was.
func skip_speech() -> bool:
	if not is_typing():
		return false
	_finish_typing()
	speech_skipped.emit(seat)
	return true


func is_typing() -> bool:
	return is_processing()


## Characters of the current line shown so far.
func shown_characters() -> int:
	return _speech.text.length() if _speech.visible_characters < 0 else _speech.visible_characters


func _process(delta: float) -> void:
	_typed += delta
	var shown: int = maxi(0, _speech.visible_characters)
	while shown < _reveal.size() and _reveal[shown] <= _typed:
		shown += 1
	if shown >= _reveal.size():
		_finish_typing()
	else:
		_speech.visible_characters = shown


func _finish_typing() -> void:
	_speech.visible_characters = -1
	set_process(false)


func _on_speech_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		if skip_speech():
			_speech.accept_event()


## Dims the portrait for a moment, as a flicker (P3B.12). The tween belongs to the
## picture, so it dies with it.
func blink(seconds: float) -> void:
	var tween: Tween = _picture.create_tween()
	tween.tween_property(_picture, "modulate:v", 0.1, seconds * 0.3)
	tween.tween_property(_picture, "modulate:v", 1.0, seconds * 0.7)


func speech() -> String:
	return _speech.text


func mood() -> String:
	return _mood
