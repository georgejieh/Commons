class_name NoticeBoard
extends HBoxContainer
## The player's Cadres as portrait cards pinned in slot order. Slots are made once. A card
## shows its art alone; its name and rules are in its tooltip, a slip that also says
## what each keyword in the rules means.

## How faint an empty Cadre slot is.
const EMPTY_ALPHA: float = 0.22
const TILE_SIZE: Vector2 = Vector2(108, 140)

var _pictures: Array[TextureRect] = []
var _cards: Array[TipHost] = []


## Makes one slot per Cadre the player can hold.
func setup(slots: int) -> void:
	add_theme_constant_override("separation", 14)
	for _index: int in slots:
		var card: TipHost = TipHost.new()
		card.custom_minimum_size = TILE_SIZE
		card.add_theme_stylebox_override("panel", ScreenKit.paper_style(6))
		var picture: TextureRect = TextureRect.new()
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(picture)
		add_child(card)
		_cards.append(card)
		_pictures.append(picture)


## Shows the Cadres the run holds, each with its name and rules as its tooltip.
func show_cadres(controller: RunController) -> void:
	var cadre_ids: Array[String] = controller.state_copy().inventory.cadres
	for index: int in _cards.size():
		var held: bool = index < cadre_ids.size()
		# An empty slot is a faint pin mark on the board, so it doesn't pull the eye.
		_cards[index].modulate.a = 1.0 if held else EMPTY_ALPHA
		if held:
			var name: String = tr("modifier.%s.name" % cadre_ids[index])
			_cards[index].set_tip(name, ScreenKit.rule_text(controller, cadre_ids[index]))
		else:
			_cards[index].set_tip("", "")
		_pictures[index].texture = ScreenKit.cadre_art(cadre_ids[index]) if held else null
