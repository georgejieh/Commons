class_name UiStyle
extends Resource
## The demo UI's design tokens: colors, radii, borders, spacing and type sizes. The theme
## builder and the screens read these, so the look changes in one place.

@export_group("Color")
## The black of print and outlines.
@export var ink: Color = Color("1e1a16")
## A lighter ink, for secondary text and rules.
@export var ink_soft: Color = Color("3a322a")
## The card stock panels and cards are made of.
@export var paper: Color = Color("efe3c8")
## A brighter paper, for what stands out against it.
@export var paper_bright: Color = Color("fbf6ea")
## The red of a signal, with one meaning: a stamp, a refusal, the main action.
@export var vermilion: Color = Color("b02a17")
## The gold of a signal, with one meaning: this is the thing.
@export var gold: Color = Color("e0b84a")
## The ink that dyes the card stock of a ticket button for the main action.
@export var ticket_red: Color = Color("cf3d25")
## The ink that dyes the card stock of the other ticket buttons: kraft brown.
@export var ticket_kraft: Color = Color("8a745c")
## The ink that dyes the card stock of a ticket button for buying: ration green.
@export var ticket_green: Color = Color("86b878")

@export_group("Shape")
## Corner radius of buttons and chips, in pixels. Paper panels keep their torn edges.
@export var radius: int = 3
## Width of a button's border, in pixels.
@export var border: int = 2
## How far a resting button's hard shadow drops, in pixels.
@export var shadow_drop: int = 5
## How far a pressed button's hard shadow drops, in pixels.
@export var pressed_drop: int = 1
## The focus ring's width, in pixels.
@export var focus_width: int = 3
## The focus ring's gap from the control, in pixels.
@export var focus_gap: int = 4

@export_group("Spacing")
## A button's padding left and right, in pixels.
@export var pad_x: int = 26
## A button's padding above and below, in pixels.
@export var pad_y: int = 12
## The gap between neighbours in a row or column, in pixels.
@export var gap: int = 16

@export_group("Type")
## Font size of running text at the Standard text size, in pixels.
@export var body_size: int = 22
## Font size of a button's label, in pixels.
@export var button_size: int = 24
## Font size of a caption, in pixels.
@export var caption_size: int = 20
## Font size of the small label above a heading, in pixels.
@export var eyebrow_size: int = 18
## Font size of a title, in pixels.
@export var title_size: int = 40
## Font size of the largest heading, in pixels.
@export var headline_size: int = 84
## Extra space between letters in eyebrow labels, in pixels.
@export var eyebrow_tracking: int = 3
