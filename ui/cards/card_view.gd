class_name CardView
extends Control
## One card drawn from layers: frame, rank glyph, suit icon, enhancement overlay, seal
## and owner stamp. bind() is the only way to show a card; views come from CardPool and
## are reused, never instanced during a round.

signal pressed(card_id: int)
signal hovered(card_id: int)

const SUIT_GLYPHS: PackedStringArray = ["♠", "♥", "♣", "♦"]
const RED_SUITS: Array[int] = [1, 3]
const JOKER_GLYPH: String = "★"
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
## Aged card stock under every face; the scene's flat style is the fallback.
const FACE: Texture2D = preload("res://art/cards/card_face.png")
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

var card_id: int = -1

var _cursor_mark: ColorRect = ColorRect.new()

## Every tween moving this view, so a reused view can stop them all.
var _tweens: Array[Tween] = []

@onready var _frame: Panel = $Frame
@onready var _rank: Label = $Frame/Rank
@onready var _suit: Label = $Frame/Suit
@onready var _enhancement: ColorRect = $Frame/Enhancement
@onready var _seal: Label = $Frame/Seal
@onready var _stamp: Label = $Frame/Stamp
@onready var _highlight: Panel = $Highlight


func _ready() -> void:
	# The scene shares one LabelSettings; each card sizes its own glyphs.
	_rank.label_settings = _rank.label_settings.duplicate()
	var stock: StyleBoxTexture = StyleBoxTexture.new()
	stock.texture = ArtStages.resolve(FACE)
	_frame.add_theme_stylebox_override("panel", stock)
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
	_suit.text = JOKER_GLYPH if joker else SUIT_GLYPHS[card.suit()]
	var red: bool = rank == Ranks.BIG_JOKER or (not joker and RED_SUITS.has(card.suit()))
	_rank.modulate = RED if red else INK
	_suit.modulate = _rank.modulate
	_enhancement.visible = card.enhancement_id() != CardInstance.NO_ID
	_seal.visible = card.seal_id() != CardInstance.NO_ID
	_stamp.visible = card.owner_stamp() != CardInstance.NO_OWNER
	set_marked(false, false)


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
