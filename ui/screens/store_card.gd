class_name StoreCard
extends RefCounted
## One Cadre on a shop's counter (P4.10): a card of stock showing the Cadre's art, or its
## name while it has none, over its Buy button, or a sold place. Its name and rules are
## in its tooltip, and in the screen's DetailSlip under it while its button has focus,
## for keyboard and gamepad.


## The card for slot; buy is called with the card's panel when its button is pressed.
static func make(
	controller: RunController,
	desk: ShopDesk,
	slot: int,
	cadre_id: String,
	slip: DetailSlip,
	buy: Callable
) -> Control:
	var card: VBoxContainer = ScreenKit.card(StoreScreen.CARD)
	if cadre_id.is_empty():
		var sold: Label = ScreenKit.styled(_tr("store.sold"), CommonsTheme.HEADLINE)
		sold.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sold.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card.add_child(sold)
		UiMotion.stamp(sold)
		return ScreenKit.card_panel(card)
	var tip: String = ScreenKit.cadre_tip(controller, cadre_id)
	var title: String = _tr("modifier.%s.name" % cadre_id)
	card.add_child(_face(cadre_id, title))
	var button: Button = ScreenKit.button(
		_tr("store.buy").format({"price": desk.price(slot)}), CommonsTheme.COUPON
	)
	button.size_flags_horizontal = Control.SIZE_FILL
	button.disabled = not desk.can_buy(slot)
	button.tooltip_text = tip
	var panel: Control = ScreenKit.card_panel(card)
	var rule: String = ScreenKit.rule_text(controller, cadre_id)
	button.focus_entered.connect(slip.show_for.bind(panel, title, rule, false))
	button.focus_exited.connect(slip.hide_for.bind(panel))
	card.add_child(button)
	button.pressed.connect(buy.bind(panel))
	panel.tooltip_text = tip
	UiMotion.hoverable(panel)
	return panel


## The card face is the art alone. A Cadre with no art yet shows its name on the stock.
static func _face(cadre_id: String, title: String) -> Control:
	if ScreenKit.ART.cadre(cadre_id) != null:
		var picture: TextureRect = ScreenKit.cover(ScreenKit.cadre_art(cadre_id))
		picture.set_anchors_preset(Control.PRESET_TOP_LEFT)
		picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return picture
	var name: Label = ScreenKit.styled(title, CommonsTheme.TITLE)
	name.size_flags_vertical = Control.SIZE_EXPAND_FILL
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.custom_minimum_size = Vector2(300, 0)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return name


static func _tr(key: String) -> String:
	return TranslationServer.translate(key)
