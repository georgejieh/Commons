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
## The green of coupons, and of what pays them, on paper.
@export var coupon: Color = Color("3f6338")
## The lighter green of coupons shown over the dark table.
@export var coupon_on_dark: Color = Color("6f9a62")
## The deep red of a seal's ink: a landlord's mark, a lie caught, a total, a rank note.
@export var seal: Color = Color("9e1b16")
## The faded ink of a loss counted on the table.
@export var loss: Color = Color("3a322b")
## The quiet brown of what is settled or waiting: a cleared audit, an idle tally.
@export var quiet: Color = Color("8a745c")
## The near-black printed on tickets, chips and the surname's slip.
@export var ticket_ink: Color = Color("120d09")
## The red of a picked ticket and of a printed band.
@export var picked: Color = Color("9e2a1d")
## The brass ring around a ticket or paper that has the focus.
@export var focus_ring: Color = Color("b98a2c")
## The worn brown of a ticket's band, a locked ticket and a perforation.
@export var worn_print: Color = Color("7a6446")
## The dark brown edge drawn around village paper.
@export var paper_edge: Color = Color("4a3a26")
## The faint brown of a printed frame, a ledger's band and a keyword's soft words.
@export var faint_ink: Color = Color("5a4a36")
## The brown line of a fold across paper.
@export var fold: Color = Color("8a7653")
## The gold of a hint: a hinted card's edge and a usable Campaign's mark; also the gilt a
## landlord's seat is trimmed in.
@export var hint: Color = Color("c9a227")
## The cream card stock a playing card is printed on.
@export var card_stock: Color = Color("f6e6c4")
## The bright red printed on a wild card's ribbon and on a file's stamp.
@export var print_red: Color = Color("b8231a")
## The red of an ending's title and frame.
@export var ending_ink: Color = Color("9a2a1a")
## The older, darker paper of a portrait's mount and a notice posted on the wall.
@export var old_paper: Color = Color("d9c8a4")
## The wheat ochre a Quota bar and the Famine meter fill with.
@export var grain_bar: Color = Color("c8952b")
## The empty ground of a bar on the table's top bar and the Quota bar.
@export var bar_ground: Color = Color("4a4239")
## The warm gold of a met Quota's bar and of a callout's rays.
@export var glow: Color = Color("e0b23c")

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
