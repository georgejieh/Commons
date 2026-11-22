class_name StoreCard
extends RefCounted
## One Cadre on a shop's counter (P4.10): a card of stock showing the Cadre's art, or the
## printed empty frame it will sit in while it has none, then its name and its full rules
## with every value filled in, then its Buy button; or a sold place. Each keyword in the
## rules explains itself on hover, and the screen's DetailSlip shows the rules again while
## the button has focus, for keyboard and gamepad. A Cadre that seldom reaches the counter
## is stamped Scarce on its picture (ScarceStamp), and its tooltip and slip say so.

## The art's height on the card, and the type sizes, readable on a 1080 screen.
const ART_HEIGHT: float = 158.0
## The card's padding, both sides together, which the picture is narrower by.
const FACE_INSET: float = 48.0
const NAME_SIZE: int = 27
const RULE_SIZE: int = 17


## The card for slot; buy is called with the card's panel when its button is pressed.
static func make(
	controller: RunController,
	desk: ShopDesk,
	slot: int,
	cadre_id: String,
	slip: DetailSlip,
	buy: Callable,
	ink: Color = ScreenKit.RED
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
	card.add_theme_constant_override("separation", 6)
	var tip: String = ScreenKit.cadre_tip(controller, cadre_id)
	var title: String = _tr("modifier.%s.name" % cadre_id)
	var rule: String = ScreenKit.rule_text(controller, cadre_id)
	var picture: Control = face(cadre_id, StoreScreen.CARD.x)
	card.add_child(picture)
	card.add_child(words(title, rule))
	# What the slip says: the rules, and under them that it is scarce when it is.
	var told: String = rule
	if desk.is_scarce(slot):
		var stamp: ScarceStamp = ScarceStamp.new(_tr("store.scarce"), ink)
		stamp.place_on(StoreScreen.CARD.x - FACE_INSET)
		picture.add_child(stamp)
		tip += "\n" + _tr("store.scarce.note")
		told += "\n\n" + _tr("store.scarce.note")
	var button: Button = ScreenKit.button("", CommonsTheme.COUPON)
	button.size_flags_horizontal = Control.SIZE_FILL
	var coupons: int = controller.state_copy().coupons
	BuyTicket.dress(button, desk.can_buy(slot), desk.price(slot), coupons)
	button.tooltip_text = tip
	var panel: Control = ScreenKit.card_panel(card)
	button.focus_entered.connect(slip.show_for.bind(panel, title, told, false))
	button.focus_exited.connect(slip.hide_for.bind(panel))
	card.add_child(button)
	button.pressed.connect(buy.bind(panel))
	UiMotion.hoverable(panel)
	return panel


## The Cadre's art across the card's top, or the empty frame it will fill.
static func face(cadre_id: String, wide: float) -> Control:
	var extent: Vector2 = Vector2(wide - FACE_INSET, ART_HEIGHT)
	if not ScreenKit.ART.has_cadre(cadre_id):
		return ArtFrame.new(extent)
	var picture: TextureRect = TextureRect.new()
	picture.texture = ScreenKit.cadre_art(cadre_id)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.custom_minimum_size = extent
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture


## The name in dark type, then the rules with their keywords marked.
static func words(title: String, rule: String) -> Control:
	var words: VBoxContainer = VBoxContainer.new()
	words.add_theme_constant_override("separation", 2)
	words.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var name: Label = ScreenKit.label(title, NAME_SIZE)
	name.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
	var wide: float = StoreScreen.CARD.x - FACE_INSET
	NameFit.apply(name, title, wide, TextSize.px(NAME_SIZE), TextSize.least(NameFit.LEAST))
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(name)
	var rules: KeywordText = KeywordText.new()
	rules.add_theme_font_size_override("normal_font_size", TextSize.px(RULE_SIZE))
	rules.add_theme_color_override("default_color", ScreenKit.INK)
	rules.set_rule(rule)
	words.add_child(rules)
	return words


static func _tr(key: String) -> String:
	return TranslationServer.translate(key)
