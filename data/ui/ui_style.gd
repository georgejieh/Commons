class_name UiStyle
extends Resource
## The demo UI's design tokens: colors, radii, borders, spacing and type sizes. The theme
## builder and the screens read these, so the look changes in one place.

@export_group("Color")
@export var ink: Color = Color("1e1a16")
@export var ink_soft: Color = Color("3a322a")
@export var paper: Color = Color("efe3c8")
@export var paper_bright: Color = Color("fbf6ea")
@export var vermilion: Color = Color("b02a17")
@export var vermilion_dark: Color = Color("7d1c10")
@export var gold: Color = Color("e0b84a")
@export var ration_green: Color = Color("5f8a55")
@export var ration_green_dark: Color = Color("3f6338")
@export var shadow: Color = Color(0.08, 0.05, 0.03, 0.55)

@export_group("Shape")
## Corner radius of buttons and chips, in pixels. Paper panels keep their torn edges.
@export var radius: int = 3
@export var border: int = 2
## How far a resting button's hard shadow drops, and a pressed one's.
@export var shadow_drop: int = 5
@export var pressed_drop: int = 1
## The focus ring's width and gap from the control.
@export var focus_width: int = 3
@export var focus_gap: int = 4

@export_group("Spacing")
@export var pad_x: int = 26
@export var pad_y: int = 12
@export var gap: int = 16

@export_group("Type")
@export var body_size: int = 22
@export var button_size: int = 24
@export var caption_size: int = 20
@export var eyebrow_size: int = 18
@export var title_size: int = 40
@export var headline_size: int = 84
## Extra space between letters in eyebrow labels, in pixels.
@export var eyebrow_tracking: int = 3
