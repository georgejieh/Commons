class_name BuyItem
extends RefCounted
## One card for sale on a shop's stall: its real face, as the table draws it, with a Buy
## ticket that names the price, or why it cannot be bought, or that the place is sold. The
## black market's plot cards stand over their tickets at full size; the state store's
## cards for the deck stand small beside theirs, in a row of buttons. Each stall keeps one
## per offer and reaches the face and the ticket through it.

## The scene each offer's card face is made from, the same face the table draws.
const CARD_SCENE: PackedScene = preload("res://ui/cards/card_view.tscn")

## The card's face, which shows the card once the item is dressed.
var view: CardView = CARD_SCENE.instantiate()
## The Buy ticket, disabled and saying "Sold" until the item is dressed.
var buy: Button = ScreenKit.button("", CommonsTheme.COUPON)


## Builds the item in row, so the face is in the tree before it shows card, which may be
## null for a place sold this visit. At scale 1.0 the face stands over the ticket, which is
## as wide as the face; under it, the face stands beside the ticket, scaled from its
## corner into a place of its scaled size, gap away.
func _init(row: Container, card: CardInstance, scale: float, gap: int) -> void:
	var over: bool = is_equal_approx(scale, 1.0)
	var item: BoxContainer
	if over:
		item = VBoxContainer.new()
	else:
		item = HBoxContainer.new()
	item.add_theme_constant_override("separation", gap)
	row.add_child(item)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buy.text = TranslationServer.translate("store.sold")
	if over:
		_stand_over(item, card)
	else:
		_stand_beside(item, card, scale)
	buy.add_theme_font_size_override("font_size", TextSize.px(CounterPanel.BUY_SIZE))
	buy.disabled = true
	BuyTicket.readable(buy)
	item.add_child(buy)


## A card keeps a card's proportions, as the table draws it: the ticket under it may be
## wider, and the card stands centred over it, never stretched to its width. A sold place
## keeps its room, its face clear.
func _stand_over(item: BoxContainer, card: CardInstance) -> void:
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	item.add_child(view)
	view.bind(card)
	view.visible = true
	view.modulate.a = 1.0 if card != null else 0.0
	buy.custom_minimum_size = Vector2(view.custom_minimum_size.x, 0)


## The face fills a place of its scaled size, which keeps the room when the place is sold.
func _stand_beside(item: BoxContainer, card: CardInstance, scale: float) -> void:
	var holder: Control = Control.new()
	holder.custom_minimum_size = (view.custom_minimum_size * scale).floor()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	item.add_child(holder)
	holder.add_child(view)
	view.bind(card)
	view.pivot_offset = Vector2.ZERO
	view.scale = Vector2.ONE * scale
	buy.custom_minimum_size = Vector2.ZERO
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
