class_name ArtLibrary
extends Resource
## Every texture the demo's screens draw, by role, so art paths live in data.

@export var table_surface: Texture2D
@export var title: Texture2D
@export var store: Texture2D
@export var notice_wall: Texture2D
@export var card_back: Texture2D
@export var card_face: Texture2D
@export var paper: Texture2D
## The card stock at a quarter size, so its border keeps its scale on panels.
@export var panel_paper: Texture2D
@export var icon_famine: Texture2D
@export var icon_denunciation: Texture2D
@export var icon_coupon: Texture2D
@export var icon_grain: Texture2D
## Cadre portraits by modifier ID.
@export var cadres: Dictionary[String, Texture2D] = {}


func cadre(cadre_id: String) -> Texture2D:
	return cadres.get(cadre_id, null)
