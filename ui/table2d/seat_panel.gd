class_name SeatPanel
extends HBoxContainer
## One villager at the table: portrait, name, cards left, role and their last words.
## The card count announces itself at 2 and 1 cards.

const INK: Color = Color("1e1a16")
const LANDLORD_RED: Color = Color("9e1b16")
const GOLD: Color = Color("c9a227")
const PAPER: Color = Color("d9c8a4")

var seat: int = -1

var _banner: Label = Label.new()
var _portrait: ColorRect = ColorRect.new()
var _picture: TextureRect = TextureRect.new()
var _name: Label = Label.new()
var _count: Label = Label.new()
var _role: Label = Label.new()
var _speech: Label = Label.new()
var _info: VBoxContainer = VBoxContainer.new()


func _init() -> void:
	add_theme_constant_override("separation", 14)
	_info.add_theme_constant_override("separation", 4)
	_banner.text = tr("table.landlord")
	_banner.add_theme_color_override("font_color", GOLD)
	_banner.add_theme_font_size_override("font_size", 22)
	_portrait.custom_minimum_size = Vector2(110, 130)
	_portrait.color = PAPER
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picture.offset_left = 4
	_picture.offset_top = 4
	_picture.offset_right = -4
	_picture.offset_bottom = -4
	_portrait.add_child(_picture)
	_name.add_theme_font_size_override("font_size", 34)
	_name.add_theme_color_override("font_color", INK)
	_count.add_theme_font_size_override("font_size", 26)
	_count.add_theme_color_override("font_color", INK)
	_role.add_theme_font_size_override("font_size", 16)
	_role.add_theme_color_override("font_color", INK)
	_speech.add_theme_font_size_override("font_size", 20)
	_speech.add_theme_color_override("font_color", INK)
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.custom_minimum_size = Vector2(210, 0)
	add_child(_portrait)
	for child: Control in [_banner, _name, _count, _role, _speech]:
		_info.add_child(child)
	add_child(_info)


func setup(seat_index: int, display_name: String, portrait: Texture2D = null) -> void:
	seat = seat_index
	_name.text = display_name
	_picture.texture = portrait


func set_count(cards: int) -> void:
	_count.text = tr("table.cards_left").format({"count": cards})
	_count.add_theme_color_override("font_color", LANDLORD_RED if cards <= 2 else INK)


func set_role(is_landlord: bool, teammate: bool) -> void:
	_banner.visible = is_landlord
	_portrait.color = GOLD if is_landlord else PAPER
	if is_landlord:
		_role.text = tr("table.role.landlord")
	elif teammate:
		_role.text = tr("table.role.teammate")
	else:
		_role.text = tr("table.role.peasant")


func say(text: String) -> void:
	_speech.text = text
