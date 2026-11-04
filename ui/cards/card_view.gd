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
## Joker words are longer than a rank glyph, so they print smaller.
const GLYPH_SIZE: int = 40
const JOKER_SIZE: int = 20
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
	stock.texture = FACE
	_frame.add_theme_stylebox_override("panel", stock)
	var tilt: ShaderMaterial = ShaderMaterial.new()
	tilt.shader = TILT_SHADER
	_frame.material = tilt


## Shows card, or hides the view when card is null.
func bind(card: CardInstance) -> void:
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


## Selected cards lift and get a red edge; hinted cards get a gold edge.
func set_marked(selected: bool, hinted: bool) -> void:
	_highlight.visible = selected or hinted
	_highlight.modulate = RED if selected else Color("c9a227")


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
