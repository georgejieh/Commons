class_name SeatPanel
extends PanelContainer
## One villager at the table, on one paper sheet: portrait, with name, cards left and
## role level with its top, and their last words underneath. The landlord tag lies
## across the portrait's top, so it takes no line of its own. The sheet keeps one height
## whatever is said. The card count turns red at 2 and 1 cards and says so in words. A
## line types out in step with the villager's voice (P3B.13); clicking it shows the rest
## at once.

## The player skipped the line typing out, so its voice should stop.
signal speech_skipped(seat: int)
## The line typing out finished or was skipped.
signal speech_finished(seat: int)

const INK: Color = Color("1e1a16")
const LANDLORD_RED: Color = Color("9e1b16")
const GOLD: Color = Color("c9a227")
const PAPER: Color = Color("d9c8a4")
## The portrait's frame, and the picture inside it after the frame's 4 px edge.
const PORTRAIT_BOX: Vector2 = Vector2(110, 138)
const PICTURE_BOX: Vector2 = Vector2(102, 130)
## Room each side of the landlord tag's word, inside its red ground.
const TAG_MARGIN: int = 10
## Seconds a flashed word stays on the role line.
const FLASH_HOLD: float = 0.9
## The speech's type and the lines of room it keeps: at least 54 px, times the text
## size's factor, and never less than two lines of the type really stand. A line that
## would need a third line there is set smaller, down to the Standard size (ADR 0034).
const SPEECH_SIZE: int = 20
const SPEECH_LINES: int = 2
const SPEECH_ROOM: Vector2 = Vector2(200, 54)

var seat: int = -1

var _banner: Label = Label.new()
var _portrait: ColorRect = ColorRect.new()
var _picture: TextureRect = TextureRect.new()
var _name: Label = Label.new()
var _count: Label = Label.new()
var _role: Label = Label.new()
var _speech: Label = Label.new()
## What an information Cadre shows about this villager's hand; empty without one.
var _intel: Label = Label.new()
var _info: VBoxContainer = VBoxContainer.new()
var _back: TextureRect = TextureRect.new()
var _count_row: HBoxContainer = HBoxContainer.new()
var _row: HBoxContainer = HBoxContainer.new()
var _stack: VBoxContainer = VBoxContainer.new()
var _mood: String = ""
## What the role line says at rest, and the tween that puts it back after a flash.
var _role_text: String = ""
var _flash: Tween = null
## When each character of the current line shows, and how long it has been typing.
var _reveal: PackedFloat32Array = PackedFloat32Array()
var _typed: float = 0.0


func _init() -> void:
	theme_type_variation = CommonsTheme.SHEET
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 14)
	_stack.add_theme_constant_override("separation", 6)
	add_child(_stack)
	_stack.add_child(_row)
	_info.add_theme_constant_override("separation", 2)
	_info.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_banner.text = tr("table.landlord").to_upper()
	_banner.theme_type_variation = CommonsTheme.EYEBROW
	_banner.add_theme_color_override("font_color", ScreenKit.STYLE.paper_bright)
	var tag: StyleBoxFlat = StyleBoxFlat.new()
	tag.bg_color = ScreenKit.STYLE.vermilion
	tag.set_corner_radius_all(ScreenKit.STYLE.radius)
	tag.content_margin_left = TAG_MARGIN
	tag.content_margin_right = TAG_MARGIN
	_banner.add_theme_stylebox_override("normal", tag)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 6
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
	_portrait.add_child(_banner)
	_name.theme_type_variation = CommonsTheme.TITLE
	_name.add_theme_font_size_override("font_size", TextSize.px(36))
	_count.add_theme_font_size_override("font_size", TextSize.px(26))
	_count.add_theme_color_override("font_color", INK)
	_role.theme_type_variation = CommonsTheme.EYEBROW
	_speech.add_theme_font_size_override("font_size", TextSize.px(SPEECH_SIZE))
	_speech.add_theme_color_override("font_color", INK)
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Two lines of room, said or not, so the sheet never changes height; _ready makes it
	# as tall as two lines of the type really stand.
	_speech.custom_minimum_size = Vector2(SPEECH_ROOM.x, ceilf(SPEECH_ROOM.y * TextSize.factor()))
	_speech.max_lines_visible = SPEECH_LINES
	_speech.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_speech.mouse_filter = Control.MOUSE_FILTER_STOP
	_speech.gui_input.connect(_on_speech_input)
	set_process(false)
	_row.add_child(_portrait)
	_back.texture = CardBacks.picture(CardBacks.current())
	_back.custom_minimum_size = Vector2(30, 42)
	_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_count_row.add_child(_back)
	_count_row.add_child(_count)
	_intel.add_theme_font_size_override("font_size", TextSize.px(17))
	_intel.add_theme_color_override("font_color", LANDLORD_RED)
	_intel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intel.custom_minimum_size = Vector2(220, 0)
	_intel.visible = false
	for child: Control in [_name, _count_row, _role, _intel]:
		_info.add_child(child)
	_row.add_child(_info)
	_stack.add_child(_speech)


## Entering the tree turns processing back on, and a panel that has said nothing is
## not typing.
func _ready() -> void:
	set_process(false)
	_fit_banner()
	_hold_speech_room()


## The speech's room stands as tall as two lines of its type, so a line that wraps to a
## second never makes the sheet taller than it was with nothing said.
func _hold_speech_room() -> void:
	var font: Font = _speech.get_theme_font("font")
	var line: float = font.get_height(TextSize.px(SPEECH_SIZE))
	var gaps: float = _speech.get_theme_constant("line_spacing") * (SPEECH_LINES - 1)
	var tall: float = maxf(_speech.custom_minimum_size.y, ceilf(line * SPEECH_LINES + gaps))
	_speech.custom_minimum_size.y = tall


## The landlord tag is print in a fixed box on the portrait (ADR 0034): the portrait's
## width, or the tag's width at Standard where that is wider. Its word fits down, never
## under its Standard size, so the tag never reaches the name beside the portrait. The
## role line under the count says the same in type that grows.
func _fit_banner() -> void:
	var font: Font = _banner.get_theme_font("font")
	var base: int = CommonsTheme.STYLE.eyebrow_size
	var word: String = _banner.text
	var standard: float = ceilf(_tag_width(font, word, TextSize.least(base)))
	var box: float = maxf(PORTRAIT_BOX.x, standard)
	var fits: Callable = func(font_size: int) -> bool:
		return _tag_width(font, word, font_size) <= box
	_banner.add_theme_font_size_override("font_size", TextSize.fit(base, base, fits))
	_banner.offset_right = box - PORTRAIT_BOX.x


## The tag's width with its word set at font_size, its margins included.
static func _tag_width(font: Font, word: String, font_size: int) -> float:
	return font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 2 * TAG_MARGIN


## The landlord tag and the name as laid out, for tests.
func banner_rect() -> Rect2:
	return _banner.get_global_rect()


func name_rect() -> Rect2:
	return _name.get_global_rect()


func setup(seat_index: int, display_name: String, portrait: Texture2D = null) -> void:
	seat = seat_index
	_name.text = display_name
	_picture.texture = portrait


## The cards left in words as well as red ink (ADR 0035): "Only 2 cards" at two and
## "Last card" at one, so the warning does not rest on colour alone.
func set_count(cards: int) -> void:
	var text: String = SeatPanel.count_text(cards)
	if _count.text != text and not _count.text.is_empty():
		UiMotion.pulse(_count)
	_count.text = text
	_count.add_theme_color_override("font_color", LANDLORD_RED if cards <= 2 else INK)


static func count_text(cards: int) -> String:
	if cards == 1:
		return TranslationServer.translate("table.card_last")
	var key: String = "table.cards_two" if cards == 2 else "table.cards_left"
	return TranslationServer.translate(key).format({"count": cards})


func set_role(is_landlord: bool, teammate: bool) -> void:
	# The tag keeps its space either way, so the seat never changes height.
	var was_landlord: bool = _banner.modulate.a > 0.5
	_banner.modulate.a = 1.0 if is_landlord else 0.0
	_portrait.color = GOLD if is_landlord else PAPER
	if is_landlord:
		_rest_role(tr("table.role.landlord"))
	elif teammate:
		_rest_role(tr("table.role.teammate"))
	else:
		_rest_role(tr("table.role.peasant"))
	# Taking the seat is stamped onto the portrait.
	if is_landlord and not was_landlord:
		UiMotion.stamp(_banner)
		bump()


## Shows what an information Cadre reveals about this hand, or nothing.
func set_intel(text: String) -> void:
	_intel.text = text
	_intel.visible = not text.is_empty()


func intel() -> String:
	return _intel.text if _intel.visible else ""


## Says what the seat did in the bidding, in place of its role, until a landlord is
## chosen and every seat has a role to show.
func set_bid(text: String) -> void:
	_rest_role(text)


## Shows text on the role line for a moment, such as a pass, then the role again.
func flash(text: String) -> void:
	_show_role(text.to_upper())
	UiMotion.pulse(_role)
	if _flash != null and _flash.is_valid():
		_flash.kill()
	_flash = create_tween()
	_flash.tween_interval(FLASH_HOLD)
	_flash.tween_callback(func() -> void: _show_role(_role_text))


## A small swell of the whole sheet, when its villager does something.
func bump() -> void:
	UiMotion.pulse(self)


func _rest_role(text: String) -> void:
	_role_text = text.to_upper()
	if _flash == null or not _flash.is_running():
		_show_role(_role_text)


## The role line is print on the sheet beside the portrait (ADR 0034): it fits the room
## the sheet leaves it, never under its Standard size, so the sheet keeps its width.
func _show_role(text: String) -> void:
	_role.text = text
	var font: Font = _role.get_theme_font("font")
	var room: float = _info_room()
	var fits: Callable = func(font_size: int) -> bool:
		return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= room
	var base: int = CommonsTheme.STYLE.eyebrow_size
	_role.add_theme_font_size_override("font_size", TextSize.fit(base, base, fits))


## The width beside the portrait inside the sheet, or no limit before the sheet is sized.
func _info_room() -> float:
	if size.x <= 0.0:
		return INF
	var edges: float = get_theme_stylebox("panel").get_minimum_size().x
	return size.x - edges - PORTRAIT_BOX.x - _row.get_theme_constant("separation")


## Shows a line; mood is the line's mood tag. With reveal times from the voice plan
## (P3B.13) it types out, one character at each time; without, it shows at once.
func say(
	text: String, mood: String = "", reveal: PackedFloat32Array = PackedFloat32Array()
) -> void:
	_speech.text = text
	_fit_speech(text)
	_mood = mood
	_reveal = reveal
	_typed = 0.0
	_speech.visible_characters = -1 if reveal.is_empty() else 0
	set_process(not reveal.is_empty())


## The line at the text size, smaller where it would need more lines than the room has.
func _fit_speech(text: String) -> void:
	var font: Font = _speech.get_theme_font("font")
	var wide: float = maxf(_speech.size.x, _speech.custom_minimum_size.x)
	var fits: Callable = func(font_size: int) -> bool:
		var tall: float = (
			font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, wide, font_size).y
		)
		return roundi(tall / font.get_height(font_size)) <= SPEECH_LINES
	var font_size: int = TextSize.fit(SPEECH_SIZE, SPEECH_SIZE, fits)
	_speech.add_theme_font_size_override("font_size", font_size)


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
	speech_finished.emit(seat)


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
