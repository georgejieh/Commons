class_name TextSize
extends RefCounted
## The one place a font size is set from (ADR 0034). The player picks Standard, Large or
## Largest; every font size in ui/ asks px() for the size to draw at, which is the base
## size times that choice's factor, never under the floor. Text in a fixed box fits down
## from px() to least(), so it is never smaller than at Standard. Art that holds a
## letter (rank glyphs, seals, stamps) keeps its size and does not come here.

const PARAMS: SettingsParams = preload("res://data/settings/default_settings.tres")
const SETTING: String = "text_size"
const AUTOLOAD: String = "Settings"


## The size to draw text of the given Standard size at. Display type, a base of
## display_text_px or more, holds its size (ADR 0034).
static func px(base: int) -> int:
	if is_display(base):
		return base
	return maxi(roundi(base * factor()), PARAMS.least_text_px)


## True when a base size is display type, which does not grow.
static func is_display(base: int) -> bool:
	return base >= PARAMS.display_text_px


## The least a fitted text may shrink to: its Standard floor, never under the floor.
static func least(floor_size: int) -> int:
	return maxi(floor_size, PARAMS.least_text_px)


## What the chosen size multiplies a font size by.
static func factor() -> float:
	return PARAMS.text_scales[level()]


## The chosen size: 0 for Standard, up to count() - 1 for Largest. The Settings autoload
## is looked up when asked, so a tool script that compiles without autoloads still loads
## the pieces that ask here; with no Settings it is Standard.
static func level() -> int:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var store: Node = null if tree == null else tree.root.get_node_or_null(AUTOLOAD)
	var chosen: int = 0 if store == null else int(store.call("value", SETTING))
	return clampi(chosen, 0, count() - 1)


static func count() -> int:
	return PARAMS.text_scales.size()


## The largest size from px(base) down to least(floor_size) at which fits says yes, for
## text in a fixed box; least(floor_size) when none does.
static func fit(base: int, floor_size: int, fits: Callable) -> int:
	var font_size: int = px(base)
	while font_size > least(floor_size) and not bool(fits.call(font_size)):
		font_size -= 1
	return maxi(font_size, least(floor_size))
