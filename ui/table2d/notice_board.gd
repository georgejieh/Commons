class_name NoticeBoard
extends HBoxContainer
## The player's Cadres as portrait cards pinned in slot order. Slots are made once.

## How faint an empty Cadre slot is.
const EMPTY_ALPHA: float = 0.22
const TILE_WIDTH: float = 108.0
const PAPER: Color = Color("f6edd9")
const INK: Color = Color("1e1a16")

var _labels: Array[Label] = []
var _pictures: Array[TextureRect] = []
var _cards: Array[Control] = []


## Makes one slot per Cadre the player can hold.
func setup(slots: int) -> void:
	add_theme_constant_override("separation", 14)
	for _index: int in slots:
		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(TILE_WIDTH, 140)
		card.add_theme_stylebox_override("panel", ScreenKit.paper_style(6))
		var column: VBoxContainer = VBoxContainer.new()
		var picture: TextureRect = TextureRect.new()
		picture.custom_minimum_size = Vector2(0, 78)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var label: Label = Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", INK)
		label.add_theme_font_size_override("font_size", 13)
		# Long names break over two lines inside the tile instead of spilling past it.
		label.custom_minimum_size = Vector2(TILE_WIDTH - 12.0, 0)
		column.add_child(picture)
		column.add_child(label)
		card.add_child(column)
		add_child(card)
		_labels.append(label)
		_cards.append(card)
		_pictures.append(picture)


func show_cadres(cadre_ids: Array[String]) -> void:
	for index: int in _labels.size():
		var held: bool = index < cadre_ids.size()
		_labels[index].text = tr("modifier.%s.name" % cadre_ids[index]) if held else ""
		# An empty slot is a faint pin mark on the board, so it doesn't pull the eye.
		_cards[index].modulate.a = 1.0 if held else EMPTY_ALPHA
		_pictures[index].texture = ScreenKit.cadre_art(cadre_ids[index]) if held else null
