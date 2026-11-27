class_name KittyShow
extends Label
## The kitty's moment once the landlord is known: its cards dealt face up in the middle
## under their stamped name for everyone to see, then swept to the landlord.

## The kitty lies face up this long before the landlord takes it, in seconds.
const SHOW: float = 0.9
## Seconds the queue is held past the kitty's sweep, so the landlord's first play never
## lands under it.
const MARGIN: float = 0.12
## Where the kitty's cards are dealt from.
const FROM: Vector2 = Vector2(790, 200)
## Where the kitty's name stands, its middle.
const LABEL_AT: Vector2 = Vector2(790, 420)
## The size of the kitty's name at Standard.
const NAME_SIZE: int = 34
## The width of the name's ink outline, in pixels.
const OUTLINE: int = 10

var _sweep: Tween = null


func _ready() -> void:
	text = tr("keyword.kitty.name").to_upper()
	theme_type_variation = CommonsTheme.TITLE
	add_theme_font_size_override("font_size", TextSize.px(NAME_SIZE))
	add_theme_color_override("font_color", ScreenKit.STYLE.paper_bright)
	add_theme_color_override("font_outline_color", ScreenKit.INK)
	add_theme_constant_override("outline_size", OUTLINE)
	visible = false


## Lays cards face up on pile, their wild ones shown wild only when wild_shown, stamps the
## name over them, and after SHOW sweeps them to to. Returns the seconds the table's queue
## must hold so the next play lands after the sweep.
func show_cards(
	pile: TrickPile, cards: Array[CardInstance], wild_shown: bool, to: Vector2
) -> float:
	pile.clear()
	pile.show_play(cards, FROM, [], null, wild_shown)
	reset_size()
	position = LABEL_AT - size / 2.0
	visible = true
	UiMotion.stamp(self)
	UiMotion.end(_sweep)
	_sweep = create_tween()
	_sweep.tween_interval(SHOW)
	_sweep.tween_callback(pile.sweep.bind(to))
	_sweep.tween_callback(hide)
	return SHOW + UiMotion.PRESETS.sweep + MARGIN
