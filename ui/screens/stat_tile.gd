class_name StatTile
extends RefCounted
## The tiles a summary counts its figures on: a tracked caption over a big number.


## A tile whose number rolls up from nothing to value.
static func rolling(caption: String, value: float) -> Control:
	var tile: VBoxContainer = ScreenKit.card(Vector2(240, 0))
	tile.add_child(ScreenKit.eyebrow(caption))
	var number: Label = ScreenKit.styled("", CommonsTheme.TITLE)
	tile.add_child(number)
	UiMotion.count(number, 0.0, value, func(shown: float) -> String: return Strings.score(shown))
	return ScreenKit.card_panel(tile)


## A tile for one of the run's figures (ShownFigures names them), as ShownFigures shows it:
## the rolling number, or its words ("None reported", ample, fulfilled).
static func figure(caption: String, state: RunView, which: String, value: float) -> Control:
	var words: String = ShownFigures.tile_text(state, which)
	if words.is_empty():
		return rolling(caption, value)
	var tile: VBoxContainer = ScreenKit.card(Vector2(240, 0))
	tile.add_child(ScreenKit.eyebrow(caption))
	tile.add_child(ScreenKit.styled(words, CommonsTheme.TITLE))
	return ScreenKit.card_panel(tile)
