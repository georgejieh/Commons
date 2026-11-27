class_name SeatPanel
extends PanelContainer
## One villager at the table, on one paper sheet: portrait, with name, cards left and
## role level with its top, what an information Cadre reveals across the sheet's width
## under them (ADR 0034, rule 9), and their last words underneath. The card back by the
## count carries the dread's eye (BackEyes). The landlord tag lies across the portrait's
## top. The card count turns red at 2 and 1 cards and says so in words. A line types out
## in step with the villager's voice (SeatSpeech).

## The player skipped the line typing out, so its voice should stop.
signal speech_skipped(seat: int)
## The line typing out finished or was skipped.
signal speech_finished(seat: int)

## The portrait's frame, in pixels.
const PORTRAIT_BOX: Vector2 = Vector2(110, 138)
## The picture inside the frame, after the frame's 4 px edge, in pixels.
const PICTURE_BOX: Vector2 = Vector2(102, 130)
## Room each side of the landlord tag's word, inside its red ground.
const TAG_MARGIN: int = 10
## Seconds a flashed word stays on the role line.
const FLASH_HOLD: float = 0.9
## What an information Cadre reveals, at Standard.
const INTEL_SIZE: int = 17
## The cards left, at Standard; fitted down, never under Standard, to the room beside the card
## back.
const COUNT_SIZE: int = 26

## The seat this sheet shows; -1 until setup().
var seat: int = -1
## The villager's last words, under the portrait row.
var speech_line: SeatSpeech = SeatSpeech.new()
## The landlord's tag across the portrait's top, shown while the seat holds the land.
var banner: Label = Label.new()
## The villager's name, beside the portrait.
var name_label: Label = Label.new()
## The cards left, in words as well as ink.
var count: Label = Label.new()
## The seat's role in the round, or its bid while the bidding goes on.
var role: Label = Label.new()
## What an information Cadre shows about this villager's hand; empty without one.
var intel_line: Label = Label.new()
## The name, the count and the role, beside the portrait.
var info: VBoxContainer = VBoxContainer.new()
## The card back by the count, which carries the dread's eye.
var back: TextureRect = TextureRect.new()
## The card back and the count, side by side.
var count_row: HBoxContainer = HBoxContainer.new()
## The portrait and the lines beside it.
var row: HBoxContainer = HBoxContainer.new()
var _portrait: ColorRect = ColorRect.new()
var _picture: TextureRect = TextureRect.new()
## True while the intel waits for an armed Campaign to be used or put down (ADR 0034).
var _intel_away: bool = false
var _stack: VBoxContainer = VBoxContainer.new()
## What the role line says at rest, and the tween that puts it back after a flash.
var _role_text: String = ""
var _flash: Tween = null
## The landlord tag's stamp while it lands, so a role that changes first can stop it.
var _tag_stamp: Tween = null


func _init() -> void:
	theme_type_variation = CommonsTheme.SHEET
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	_stack.add_theme_constant_override("separation", 6)
	add_child(_stack)
	_stack.add_child(row)
	info.add_theme_constant_override("separation", 2)
	info.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_build_portrait()
	_build_lines()
	row.add_child(_portrait)
	_build_count()
	for child: Control in [name_label, count_row, role]:
		info.add_child(child)
	row.add_child(info)
	_stack.add_child(intel_line)
	_stack.add_child(speech_line)
	speech_line.skipped.connect(func() -> void: speech_skipped.emit(seat))
	speech_line.finished.connect(func() -> void: speech_finished.emit(seat))


## The portrait on its mount, with the landlord's tag across its top.
func _build_portrait() -> void:
	banner.text = tr("table.landlord").to_upper()
	banner.theme_type_variation = CommonsTheme.EYEBROW
	banner.add_theme_color_override("font_color", ScreenKit.STYLE.paper_bright)
	var tag: StyleBoxFlat = StyleBoxFlat.new()
	tag.bg_color = ScreenKit.STYLE.vermilion
	tag.set_corner_radius_all(ScreenKit.STYLE.radius)
	tag.content_margin_left = TAG_MARGIN
	tag.content_margin_right = TAG_MARGIN
	banner.add_theme_stylebox_override("normal", tag)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 6
	_portrait.custom_minimum_size = PORTRAIT_BOX
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_portrait.color = ScreenKit.OLD_PAPER
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_picture.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4
	)
	_portrait.add_child(_picture)
	_portrait.add_child(banner)


## The name and the role beside the portrait.
func _build_lines() -> void:
	name_label.theme_type_variation = CommonsTheme.TITLE
	name_label.add_theme_font_size_override("font_size", TextSize.px(36))
	count.add_theme_font_size_override("font_size", TextSize.px(COUNT_SIZE))
	count.add_theme_color_override("font_color", ScreenKit.INK)
	role.theme_type_variation = CommonsTheme.EYEBROW


## The card back and count of the cards left, and the intel line under the row.
func _build_count() -> void:
	back.texture = CardBacks.picture(CardBacks.current())
	back.custom_minimum_size = Vector2(30, 42)
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	back.add_child(BackEyes.new())
	count_row.add_child(back)
	count_row.add_child(count)
	intel_line.add_theme_font_size_override("font_size", TextSize.px(INTEL_SIZE))
	intel_line.add_theme_color_override("font_color", ScreenKit.SEAL)
	intel_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intel_line.visible = false


func _ready() -> void:
	_fit_banner()


## The landlord tag is print in a fixed box on the portrait (ADR 0034): the portrait's
## width, or the tag's width at Standard where that is wider. Its word fits down, never
## under its Standard size, so the tag never reaches the name beside the portrait. The
## role line under the count says the same in type that grows.
func _fit_banner() -> void:
	var font: Font = banner.get_theme_font("font")
	var base: int = CommonsTheme.STYLE.eyebrow_size
	var word: String = banner.text
	var standard: float = ceilf(_tag_width(font, word, TextSize.least(base)))
	var box: float = maxf(PORTRAIT_BOX.x, standard)
	var fits: Callable = func(font_size: int) -> bool:
		return _tag_width(font, word, font_size) <= box
	banner.add_theme_font_size_override("font_size", TextSize.fit(base, base, fits))
	banner.offset_right = box - PORTRAIT_BOX.x


## The tag's width with its word set at font_size, its margins included.
static func _tag_width(font: Font, word: String, font_size: int) -> float:
	return font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 2 * TAG_MARGIN


## Sets the seat this sheet shows, with the villager's name and portrait.
func setup(seat_index: int, display_name: String, portrait: Texture2D = null) -> void:
	seat = seat_index
	name_label.text = display_name
	_picture.texture = portrait


## The cards left in words as well as red ink (ADR 0035): "Only 2 cards" at two and
## "Last card" at one, so the warning does not rest on colour alone.
func set_count(cards: int) -> void:
	var text: String = SeatPanel.count_text(cards)
	if count.text != text and not count.text.is_empty():
		UiMotion.pulse(count)
	count.text = text
	count.add_theme_color_override("font_color", ScreenKit.SEAL if cards <= 2 else ScreenKit.INK)
	# Print beside the portrait: it fits the room the sheet leaves, never under Standard.
	var font: Font = count.get_theme_font("font")
	var gap: float = count_row.get_theme_constant("separation")
	var room: float = _info_room() - back.custom_minimum_size.x - gap
	var fits: Callable = func(font_size: int) -> bool:
		return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= room
	count.add_theme_font_size_override("font_size", TextSize.fit(COUNT_SIZE, COUNT_SIZE, fits))


## The cards-left line for a count: "Last card" at one, "Only 2 cards" at two, else "N cards".
static func count_text(cards: int) -> String:
	if cards == 1:
		return TranslationServer.translate("table.card_last")
	var key: String = "table.cards_two" if cards == 2 else "table.cards_left"
	return TranslationServer.translate(key).format({"count": cards})


## Shows the seat's role: the landlord's tag and stamp, else teammate or peasant.
func set_role(is_landlord: bool, teammate: bool) -> void:
	# The tag keeps its space either way, so the seat never changes height.
	var was_landlord: bool = banner.modulate.a > 0.5
	# A stamp still landing would bring the tag back after the seat lost it.
	if _tag_stamp != null and _tag_stamp.is_valid():
		_tag_stamp.kill()
		banner.scale = Vector2.ONE
		banner.rotation = 0.0
	banner.modulate.a = 1.0 if is_landlord else 0.0
	_portrait.color = ScreenKit.HINT if is_landlord else ScreenKit.OLD_PAPER
	if is_landlord:
		_rest_role(tr("table.role.landlord"))
	elif teammate:
		_rest_role(tr("table.role.teammate"))
	else:
		_rest_role(tr("table.role.peasant"))
	# Taking the seat is stamped onto the portrait.
	if is_landlord and not was_landlord:
		_tag_stamp = UiMotion.stamp(banner)
		bump()


## Shows what an information Cadre reveals about this hand, or nothing.
func set_intel(text: String) -> void:
	intel_line.text = text
	intel_line.visible = not text.is_empty() and not _intel_away
	# The sheet stands as tall as it needs, shorter again once the line goes.
	fit_intel(TextSize.px(INTEL_SIZE))


## Sets the intel line at font_size, across the sheet's inner width. Its column may fit it
## down, never under its Standard size (ADR 0034, rule 9).
func fit_intel(font_size: int) -> void:
	var edges: float = get_theme_stylebox("panel").get_minimum_size().x
	intel_line.custom_minimum_size.x = maxf(size.x - edges, 0.0)
	intel_line.add_theme_font_size_override(
		"font_size", maxi(font_size, TextSize.least(INTEL_SIZE))
	)
	_stand_again()


## Puts the intel line away, taking no room, or brings it back.
func put_away_intel(away: bool) -> void:
	if away == _intel_away:
		return
	_intel_away = away
	intel_line.visible = not intel_line.text.is_empty() and not away
	_stand_again()


## The sheet at the height its lines need now, its width kept. Each cached minimum size
## is thrown out by hand, innermost first: Godot can leave a stale one standing.
func _stand_again() -> void:
	for control: Control in [intel_line, _stack, self]:
		control.update_minimum_size()
	size = Vector2(size.x, 0.0)


## True while the intel line shows.
func has_intel() -> bool:
	return intel_line.visible


## The type the intel line is set in now, which the column fits to the sheets.
func intel_size() -> int:
	return intel_line.get_theme_font_size("font_size")


## The intel line as shown, or empty while it is hidden, for tests.
func intel() -> String:
	return intel_line.text if intel_line.visible else ""


## Says what the seat did in the bidding, in place of its role, until a landlord is
## chosen and every seat has a role to show.
func set_bid(text: String) -> void:
	_rest_role(text)


## Shows text on the role line for a moment, such as a pass, then the role again.
func flash(text: String) -> void:
	_show_role(text.to_upper())
	UiMotion.pulse(role)
	UiMotion.end(_flash)
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
	role.text = text
	var font: Font = role.get_theme_font("font")
	var room: float = _info_room()
	var fits: Callable = func(font_size: int) -> bool:
		return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= room
	var base: int = CommonsTheme.STYLE.eyebrow_size
	role.add_theme_font_size_override("font_size", TextSize.fit(base, base, fits))


## The width beside the portrait inside the sheet, or no limit before the sheet is sized.
func _info_room() -> float:
	if size.x <= 0.0:
		return INF
	var edges: float = get_theme_stylebox("panel").get_minimum_size().x
	return size.x - edges - PORTRAIT_BOX.x - row.get_theme_constant("separation")


## Shows a line, typing out at the voice plan's reveal times when it has them.
func say(text: String, reveal: PackedFloat32Array = PackedFloat32Array()) -> void:
	speech_line.say(text, reveal)


## Shows the rest of a line still typing out. True if one was.
func skip_speech() -> bool:
	return speech_line.skip()


## True while the villager's line is still typing out, for tests.
func is_typing() -> bool:
	return speech_line.is_typing()


## Characters of the current line shown so far.
func shown_characters() -> int:
	return speech_line.shown_characters()


## Dims the portrait for a moment, as a flicker. The tween belongs to the picture, so it
## dies with it.
func blink(seconds: float) -> void:
	var tween: Tween = _picture.create_tween()
	tween.tween_property(_picture, "modulate:v", 0.1, seconds * 0.3)
	tween.tween_property(_picture, "modulate:v", 1.0, seconds * 0.7)


## The villager's last words as shown, for tests.
func speech() -> String:
	return speech_line.text
