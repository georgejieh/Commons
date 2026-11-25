class_name ArtLibrary
extends Resource
## Every texture the demo's screens draw, by role, so art paths live in data. Cadre and
## ending pictures are file paths, loaded only when a screen shows one (ScreenKit), so the
## library itself holds none of them in memory.

## The cloth under the table.
@export var table_surface: Texture2D
## The poster behind the title screen.
@export var title: Texture2D
## The backdrop of the state store.
@export var store: Texture2D
## The wall of notices behind the pages that list the run's things.
@export var notice_wall: Texture2D
## The village at night, for the title.
@export var title_night: Texture2D
## Faint eyes on black, added over the table's darkness.
@export var watchers: Texture2D
## The back of every card.
@export var card_back: Texture2D
## The card stock, for a page with no backdrop of its own.
@export var paper: Texture2D
## The card stock at a quarter size, so its border keeps its scale on panels.
@export var panel_paper: Texture2D
## The Famine meter's icon.
@export var icon_famine: Texture2D
## The Denunciation meter's icon.
@export var icon_denunciation: Texture2D
## The ration coupon beside the meters.
@export var icon_coupon: Texture2D
## Cadre portraits by modifier ID, as file paths.
@export var cadres: Dictionary[String, String] = {}
## Ending pictures by ending ID (ADR 0024), as file paths. An ending with none shows its
## title in type.
@export var endings: Dictionary[String, String] = {}
## How many Cadre and ending pictures stay loaded once off screen; the least recently
## shown is dropped first.
@export var picture_cache: int = 12
## A face holding the Chinese characters drawn as decoration, such as Struggled's seal.
## Without one, or without the characters, the decoration is left out, never drawn as
## missing-glyph boxes.
@export var hanzi_font: Font


func has_cadre(cadre_id: String) -> bool:
	return not cadre_path(cadre_id).is_empty()


## The Cadre's picture file, or "" while it has none.
func cadre_path(cadre_id: String) -> String:
	return cadres.get(cadre_id, "")


## The ending's picture file, or "" while it has none.
func ending_path(ending_id: String) -> String:
	return endings.get(ending_id, "")
