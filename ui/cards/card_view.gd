class_name CardView
extends Control
## One card composed from layers (P3C.5): frame, rank glyph from the font, suit icon,
## a picture, enhancement overlay, seal and owner stamp. A number card shows its suit
## faintly in the corner; a court card or joker is a picture card, its art filling the
## face and fading to bare card stock in the corner, where the rank and suit are printed
## straight on, as on a playing card.
## A note under the index says when a debuff makes the card rank as another. The parts
## come from CardArt, so no face is baked. bind() is the only way to show a card; views
## come from CardPool and are reused, never instanced during a round.

signal pressed(card_id: int)
signal hovered(card_id: int)

const RED_SUITS: Array[int] = [1, 3]
const INK: Color = Color("1e1a16")
const RED: Color = Color("b02a17")
const HINT: Color = Color("c9a227")
const CURSOR: Color = Color("f4ecd8")
## Height of the cursor's bar under the card.
const CURSOR_BAR: float = 8.0
## Joker words are longer than a rank glyph, so they print smaller.
const GLYPH_SIZE: int = 40
const JOKER_SIZE: int = 24
const TILT_SHADER: Shader = preload("res://shaders/card_tilt.gdshader")
const ART: CardArt = preload("res://data/ui/card_art.tres")
## Where a number card's faint suit sits, and the inset of a picture card's art, as
## left, top, right and bottom offsets.
const PIP_BOX: Vector4 = Vector4(46, 56, 112, 160)
const ART_BOX: Vector4 = Vector4(5, 5, 115, 163)
## The corner of a picture card where the art fades to card stock: its size for a court
## card and for a joker's word, the stock's color, and how far in the fade stays solid.
const FADE_SIZE: Vector2 = Vector2(92, 136)
const JOKER_FADE_SIZE: Vector2 = Vector2(120, 78)
const STOCK: Color = Color("f6e6c4")
const FADE_SOLID: float = 0.45
## A paper edge around a picture card's rank, so it reads over any art.
const RANK_OUTLINE: int = 6
const NOTE_COLOR: Color = Color("9e1b16")
const RANK_KEYS: PackedStringArray = [
	"card.rank.3",
	"card.rank.4",
	"card.rank.5",
	"card.rank.6",
	"card.rank.7",
	"card.rank.8",
	"card.rank.9",
	"card.rank.10",
	"card.rank.j",
	"card.rank.q",
	"card.rank.k",
	"card.rank.a",
	"card.rank.2",
	"card.rank.small_joker",
	"card.rank.big_joker",
]

## Tests may swap the parts; null means the shipped art.
static var art_override: CardArt = null

var card_id: int = -1

var _cursor_mark: ColorRect = ColorRect.new()

## Every tween moving this view, so a reused view can stop them all.
var _tweens: Array[Tween] = []

@onready var _frame: Panel = $Frame
@onready var _rank: Label = $Frame/Rank
@onready var _suit: TextureRect = $Frame/Suit
@onready var _picture: TextureRect = $Frame/Picture
@onready var _index: TextureRect = $Frame/Index
@onready var _rank_note: Label = $Frame/RankNote
@onready var _enhancement: ColorRect = $Frame/Enhancement
@onready var _seal: Label = $Frame/Seal
@onready var _stamp: Label = $Frame/Stamp
@onready var _highlight: Panel = $Highlight


func _ready() -> void:
	# The scene shares one LabelSettings; each card sizes its own glyphs.
	_rank.label_settings = _rank.label_settings.duplicate()
	var stock: StyleBoxTexture = StyleBoxTexture.new()
	stock.texture = Lighting.lit(ArtStages.resolve(parts().frame))
	_frame.add_theme_stylebox_override("panel", stock)
	_frame.light_mask = Lighting.MASK
	var tilt: ShaderMaterial = ShaderMaterial.new()
	tilt.shader = TILT_SHADER
	_frame.material = tilt
	_cursor_mark.color = CURSOR
	_cursor_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_mark.visible = false
	_cursor_mark.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_cursor_mark.offset_top = CURSOR_BAR
	_cursor_mark.offset_bottom = CURSOR_BAR * 2.0
	add_child(_cursor_mark)
	var tag: StyleBoxFlat = StyleBoxFlat.new()
	tag.bg_color = NOTE_COLOR
	tag.set_corner_radius_all(4)
	_rank_note.add_theme_stylebox_override("normal", tag)
	_index.texture = _corner_fade()
	_rank.label_settings.outline_color = STOCK


## The card parts in use.
static func parts() -> CardArt:
	return art_override if art_override != null else ART


## A tween on this view that settle() can stop.
func tween() -> Tween:
	var made: Tween = create_tween()
	_tweens.append(made)
	return made


## Stops every tween and puts the view back to rest: full size, upright, opaque, with
## its pivot at the bottom middle. Pooled views pass through here whenever they move.
func settle() -> void:
	for running: Tween in _tweens:
		if running != null and running.is_valid():
			running.kill()
	_tweens.clear()
	scale = Vector2.ONE
	rotation = 0.0
	modulate = Color.WHITE
	pivot_offset = Vector2(size.x / 2.0, size.y)
	z_index = 0


## Shows card, or hides the view when card is null.
func bind(card: CardInstance) -> void:
	settle()
	visible = card != null
	if card == null:
		card_id = -1
		return
	card_id = card.id()
	var rank: int = card.base_rank()
	_rank.text = tr(RANK_KEYS[rank])
	var joker: bool = rank >= Ranks.SMALL_JOKER
	_rank.label_settings.font_size = JOKER_SIZE if joker else GLYPH_SIZE
	var art: CardArt = parts()
	_suit.visible = not joker
	if not joker:
		_suit.texture = ArtStages.resolve(art.suits[card.suit()])
	_picture.texture = ArtStages.resolve(art.picture(rank, card.suit()))
	var pip: bool = rank < Ranks.JACK or (rank > Ranks.KING and not joker)
	_picture.modulate.a = art.pip_alpha if pip else 1.0
	_lay_out_face(pip, joker)
	var red: bool = rank == Ranks.BIG_JOKER or (not joker and RED_SUITS.has(card.suit()))
	_rank.label_settings.font_color = RED if red else INK
	_enhancement.visible = card.enhancement_id() != CardInstance.NO_ID
	_seal.visible = card.seal_id() != CardInstance.NO_ID
	_stamp.visible = card.owner_stamp() != CardInstance.NO_OWNER
	set_rank_note("")
	set_marked(false, false)


## Says the card ranks as another, such as "as 3", or hides the note when text is empty.
func set_rank_note(text: String) -> void:
	_rank_note.text = text
	_rank_note.visible = not text.is_empty()


func rank_note() -> String:
	return _rank_note.text if _rank_note.visible else ""


## True when the face is a picture card: art over the whole face under a corner index.
func is_picture_card() -> bool:
	return _index.visible


## A number card shows its suit faintly in the corner; a picture card's art fills the
## face, with the rank and suit on a paper index sized to the rank.
func _lay_out_face(pip: bool, joker: bool) -> void:
	var box: Vector4 = PIP_BOX if pip else ART_BOX
	_picture.offset_left = box.x
	_picture.offset_top = box.y
	_picture.offset_right = box.z
	_picture.offset_bottom = box.w
	_picture.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED if pip else TextureRect.STRETCH_KEEP_ASPECT_COVERED
	)
	_index.visible = not pip
	_rank.label_settings.outline_size = 0 if pip else RANK_OUTLINE
	_index.size = JOKER_FADE_SIZE if joker else FADE_SIZE


## Card stock that is solid in the top left corner and fades out toward the art.
static func _corner_fade() -> GradientTexture2D:
	var fade: Gradient = Gradient.new()
	fade.set_color(0, STOCK)
	fade.set_color(1, Color(STOCK, 0.0))
	fade.add_point(FADE_SOLID, Color(STOCK, 0.92))
	var corner: GradientTexture2D = GradientTexture2D.new()
	corner.gradient = fade
	corner.fill = GradientTexture2D.FILL_RADIAL
	corner.fill_from = Vector2.ZERO
	corner.fill_to = Vector2(1.0, 1.0)
	corner.width = 64
	corner.height = 64
	return corner


## Selected cards lift and get a red edge; hinted cards get a gold edge. The keyboard
## and gamepad cursor gets its own paper-white bar under the card, so it shows on a
## selected card too.
func set_marked(selected: bool, hinted: bool, cursor: bool = false) -> void:
	_highlight.visible = selected or hinted
	_highlight.modulate = RED if selected else HINT
	_cursor_mark.visible = cursor


func has_cursor() -> bool:
	return _cursor_mark.visible


func _gui_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		_set_tilt(motion.position / size * 2.0 - Vector2.ONE)
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(card_id)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		hovered.emit(card_id)
	elif what == NOTIFICATION_MOUSE_EXIT:
		_set_tilt(Vector2.ZERO)


func _set_tilt(tilt: Vector2) -> void:
	var tilt_material: ShaderMaterial = _frame.material as ShaderMaterial
	if tilt_material != null:
		tilt_material.set_shader_parameter("tilt", tilt.clamp(-Vector2.ONE, Vector2.ONE))
