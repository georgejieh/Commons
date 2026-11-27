class_name CardView
extends Control
## One card composed from layers: frame, rank glyph from the font, suit icon,
## a picture, enhancement overlay, seal, and the marks that outlast a round, both on the
## left edge a fan leaves showing: an enhancement's mark under the suit pip (CardMark: a
## Model card's rosette, a Sheaf, a Pennant or a Surplus coupon), a red chop at the foot
## for an owner's stamp. A number card shows its suit
## faintly in the corner; a court card or joker is a picture card, its art filling the
## face and fading to bare card stock in the corner, where the rank and suit are printed
## straight on, as on a playing card.
## A wild card (ADR 0029) carries a red ribbon down the same edge, under the index.
## A note under the index says when a debuff makes the card rank as another, or what a
## played wild card stands in for. The parts
## come from CardArt, so no face is baked. bind() is the only way to show a card; views
## come from CardPool and are reused, never instanced during a round.

## Emitted with the card's id when the card is clicked.
signal pressed(card_id: int)
## Emitted with the card's id when the pointer enters the card.
signal hovered(card_id: int)

## The suits printed in red, as suit indexes.
const RED_SUITS: Array[int] = [1, 3]
## The edge of a selection that makes a legal play: ready to throw.
const ARMED: Color = Color("f2c94c")
## The color of the keyboard cursor's bar under the card.
const CURSOR: Color = Color("f4ecd8")
## Height of the cursor's bar under the card.
const CURSOR_BAR: float = 8.0
## The type size of a rank glyph.
const GLYPH_SIZE: int = 40
## The smaller type size of a joker's word, which is longer than a rank glyph.
const JOKER_SIZE: int = 24
## The shader that tilts the card toward the pointer.
const TILT_SHADER: Shader = preload("res://shaders/card_tilt.gdshader")
## The card art every face is composed from, unless a view is given its own.
const ART: CardArt = preload("res://data/ui/card_art.tres")
## Where a number card's faint suit sits, as left, top, right and bottom offsets.
const PIP_BOX: Vector4 = Vector4(46, 56, 112, 160)
## The inset of a picture card's art, as left, top, right and bottom offsets.
const ART_BOX: Vector4 = Vector4(5, 5, 115, 163)
## The corner of a picture card where the art fades to card stock: its size for a court
## card.
const FADE_SIZE: Vector2 = Vector2(92, 136)
## The size of that corner for a joker's word.
const JOKER_FADE_SIZE: Vector2 = Vector2(120, 78)
## How far in from the edge of the corner the fade stays solid, as a share of it.
const FADE_SOLID: float = 0.45
## A paper edge around a picture card's rank, so it reads over any art.
const RANK_OUTLINE: int = 6
## Where a stamp's chop sits: at the foot of the left edge, the strip a fanned hand
## leaves showing, inside the selection edge.
const CHOP_AT: Vector2 = Vector2(9, 128)
## Where an enhancement's mark sits: down the same edge, under the suit pip.
const ENHANCEMENT_AT: Vector2 = Vector2(13, 92)
## Under a rank note the enhancement's mark moves down beside the chop, clear of the note.
const ENHANCEMENT_BY_NOTE: Vector2 = Vector2(40, 128)
## Where an enhancement's mark sits on a wild card: right of the ribbon that hangs down
## the very edge (ADR 0029).
const ENHANCEMENT_BY_RIBBON: Vector2 = Vector2(16, 92)
## The rank note's left and right offsets on an ordinary card.
const NOTE_SPAN: Vector2 = Vector2(8, 72)
## The same offsets on a wild card: right of its ribbon, and narrowed so the note still
## shows where the next card lies.
const NOTE_SPAN_BY_RIBBON: Vector2 = Vector2(15, 61)
## The rank note's type size.
const NOTE_SIZE: int = 18
## The height of the note's tag on the card: the card is art of a fixed size, so the note
## grows with the text size only as far as its tag holds it.
const NOTE_TALL: float = 26.0
## The string keys of the ranks' names, indexed by rank.
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
## What every view draws the same, made once and shared: the card stock for the frame art
## it was made from, the rank note's tag, and the picture card's corner fade. Nothing
## changes them once made; each view keeps its own tilt material.
static var _stock: StyleBoxTexture = null
static var _stock_of: Texture2D = null
static var _note_tag: StyleBoxFlat = null
static var _fade: GradientTexture2D = null

## The id of the card shown, or -1 while the view is unbound.
var card_id: int = -1

## The hint's tick in the card's corner.
var tick: HintTick = HintTick.new()
## The Model mark.
var badge: CardMark = CardMark.new(CardMark.Kind.MODEL)
## The owner's stamp.
var chop: CardMark = CardMark.new(CardMark.Kind.STAMP)
var _cursor_mark: ColorRect = ColorRect.new()
var _ribbon: WildRibbon = WildRibbon.new()

## Every tween moving this view, so a reused view can stop them all.
var _tweens: Array[Tween] = []

## The card's face.
@onready var frame_panel: Panel = $Frame
## The rank in the corner.
@onready var rank_label: Label = $Frame/Rank
## The suit under the rank.
@onready var suit: TextureRect = $Frame/Suit
## The card's picture.
@onready var picture: TextureRect = $Frame/Picture
@onready var _index: TextureRect = $Frame/Index
@onready var _rank_note: Label = $Frame/RankNote
@onready var _enhancement: ColorRect = $Frame/Enhancement
@onready var _seal: Label = $Frame/Seal
@onready var _highlight: Panel = $Highlight


func _ready() -> void:
	frame_panel.add_theme_stylebox_override("panel", _card_stock())
	frame_panel.light_mask = Lighting.MASK
	var tilt: ShaderMaterial = ShaderMaterial.new()
	tilt.shader = TILT_SHADER
	frame_panel.material = tilt
	_cursor_mark.color = CURSOR
	_cursor_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_mark.visible = false
	_cursor_mark.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_cursor_mark.offset_top = CURSOR_BAR
	_cursor_mark.offset_bottom = CURSOR_BAR * 2.0
	add_child(_cursor_mark)
	add_child(tick)
	_rank_note.add_theme_stylebox_override("normal", _rank_note_tag())
	_index.texture = _corner_fade()
	rank_label.add_theme_color_override("font_outline_color", ScreenKit.CARD_STOCK)
	for mark: CardMark in [chop, badge]:
		frame_panel.add_child(mark)
	frame_panel.add_child(_ribbon)
	chop.position = CHOP_AT
	badge.position = ENHANCEMENT_AT


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
	rank_label.text = tr(RANK_KEYS[rank])
	var joker: bool = rank >= Ranks.SMALL_JOKER
	rank_label.add_theme_font_size_override("font_size", JOKER_SIZE if joker else GLYPH_SIZE)
	var art: CardArt = parts()
	suit.visible = not joker
	if not joker:
		suit.texture = ArtStages.resolve(art.suits[card.suit()])
	picture.texture = ArtStages.resolve(art.picture(rank, card.suit()))
	var pip: bool = rank < Ranks.JACK or (rank > Ranks.KING and not joker)
	picture.modulate.a = art.pip_alpha if pip else 1.0
	_lay_out_face(pip, joker)
	var red: bool = rank == Ranks.BIG_JOKER or (not joker and RED_SUITS.has(card.suit()))
	rank_label.add_theme_color_override("font_color", ScreenKit.RED if red else ScreenKit.INK)
	var enhancement: String = card.enhancement_id()
	var drawn: bool = CardMark.draws(enhancement)
	_enhancement.visible = enhancement != CardInstance.NO_ID and not drawn
	badge.visible = drawn
	if drawn and badge.kind != CardMark.KINDS[enhancement]:
		badge.kind = CardMark.KINDS[enhancement]
		badge.queue_redraw()
	_seal.visible = card.seal_id() != CardInstance.NO_ID
	chop.visible = card.owner_stamp() != CardInstance.NO_OWNER
	_ribbon.show_on(false)
	set_rank_note("")
	set_marked(false, false)


## Says the card ranks as another, such as "as 3", or hides the note when text is empty.
## A stand-in on the pile names the rank it stands for the same way (ADR 0029).
func set_rank_note(text: String) -> void:
	_rank_note.text = text
	_rank_note.visible = not text.is_empty()
	_place_marks()
	_rank_note.add_theme_font_size_override("font_size", _note_size(text))


## Says the card ranks as rank, such as "as 3", in the rank note.
func set_rank_as(rank: int) -> void:
	set_rank_note(tr("card.rank_as").format({"rank": tr(RANK_KEYS[rank])}))


func _note_size(text: String) -> int:
	var font: Font = _rank_note.get_theme_font("font")
	var wide: float = _rank_note.offset_right - _rank_note.offset_left
	var tall: float = maxf(NOTE_TALL, font.get_height(NOTE_SIZE))
	var fits: Callable = func(font_size: int) -> bool:
		var line: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		return line.x <= wide and font.get_height(font_size) <= tall
	return TextSize.fit(NOTE_SIZE, NOTE_SIZE, fits)


## The text of the rank note, or "" when none shows; for tests.
func rank_note() -> String:
	return _rank_note.text if _rank_note.visible else ""


## Hangs the wild card's ribbon on this card, or takes it off (ADR 0029).
func set_wild(on: bool) -> void:
	if on == _ribbon.visible:
		return
	_ribbon.show_on(on, card_id)
	_place_marks()


## True while the wild card's ribbon hangs on the card; for tests.
func shows_wild() -> bool:
	return _ribbon.visible


## The ribbon's box on the card, in card pixels, for tests.
func ribbon_rect() -> Rect2:
	return Rect2(_ribbon.position, _ribbon.size)


## The enhancement's mark and the rank note keep clear of each other and of the ribbon.
func _place_marks() -> void:
	var span: Vector2 = NOTE_SPAN_BY_RIBBON if _ribbon.visible else NOTE_SPAN
	_rank_note.offset_left = span.x
	_rank_note.offset_right = span.y
	if _rank_note.visible:
		badge.position = ENHANCEMENT_BY_NOTE
	else:
		badge.position = ENHANCEMENT_BY_RIBBON if _ribbon.visible else ENHANCEMENT_AT


## True while the card shows a stamp's chop; for tests and playtests.
func shows_stamp() -> bool:
	return chop.visible


## The enhancement whose mark the card shows, or CardInstance.NO_ID for none; for tests.
func shown_enhancement() -> String:
	if not badge.visible:
		return CardInstance.NO_ID
	return CardMark.KINDS.find_key(badge.kind)


## True when the face is a picture card: art over the whole face under a corner index.
func is_picture_card() -> bool:
	return _index.visible


## A number card shows its suit faintly in the corner; a picture card's art fills the
## face, with the rank and suit on a paper index sized to the rank.
func _lay_out_face(pip: bool, joker: bool) -> void:
	var box: Vector4 = PIP_BOX if pip else ART_BOX
	picture.offset_left = box.x
	picture.offset_top = box.y
	picture.offset_right = box.z
	picture.offset_bottom = box.w
	picture.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED if pip else TextureRect.STRETCH_KEEP_ASPECT_COVERED
	)
	_index.visible = not pip
	rank_label.add_theme_constant_override("outline_size", 0 if pip else RANK_OUTLINE)
	_index.size = JOKER_FADE_SIZE if joker else FADE_SIZE


## The frame's card stock for the art in use at this stage, lit; made again only when
## that art is another.
static func _card_stock() -> StyleBoxTexture:
	var frame: Texture2D = ArtStages.resolve(parts().frame)
	if _stock == null or _stock_of != frame:
		_stock = StyleBoxTexture.new()
		_stock.texture = Lighting.lit(frame)
		_stock_of = frame
	return _stock


## The rank note's red tag.
static func _rank_note_tag() -> StyleBoxFlat:
	if _note_tag == null:
		_note_tag = StyleBoxFlat.new()
		_note_tag.bg_color = ScreenKit.SEAL
		_note_tag.set_corner_radius_all(4)
	return _note_tag


## Card stock that is solid in the top left corner and fades out toward the art.
static func _corner_fade() -> GradientTexture2D:
	if _fade != null:
		return _fade
	var fade: Gradient = Gradient.new()
	fade.set_color(0, ScreenKit.CARD_STOCK)
	fade.set_color(1, Color(ScreenKit.CARD_STOCK, 0.0))
	fade.add_point(FADE_SOLID, Color(ScreenKit.CARD_STOCK, 0.92))
	var corner: GradientTexture2D = GradientTexture2D.new()
	corner.gradient = fade
	corner.fill = GradientTexture2D.FILL_RADIAL
	corner.fill_from = Vector2.ZERO
	corner.fill_to = Vector2(1.0, 1.0)
	corner.width = 64
	corner.height = 64
	_fade = corner
	return corner


## Selected cards lift and get a red edge, which turns bright gold once the selection
## is a play that can be made; hinted cards get a gold edge and a pencilled tick above
## the edge the fan leaves showing, which stays when the card is also selected, so the
## hint never rests on colour alone (ADR 0035). The keyboard and gamepad cursor gets its
## own paper-white bar under the card, so it shows on a selected card too.
func set_marked(selected: bool, hinted: bool, cursor: bool = false, armed: bool = false) -> void:
	_highlight.visible = selected or hinted
	_highlight.modulate = (ARMED if armed else ScreenKit.RED) if selected else ScreenKit.HINT
	_cursor_mark.visible = cursor
	tick.show_on(hinted, card_id)


## True while the hint's tick shows on the card; for tests.
func shows_hint_tick() -> bool:
	return tick.visible


## The tick's box on the card, in card pixels, for tests.
func hint_tick_rect() -> Rect2:
	return Rect2(tick.position, tick.size)


## True while the keyboard cursor's bar shows under the card; for tests.
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
	var tilt_material: ShaderMaterial = frame_panel.material as ShaderMaterial
	if tilt_material != null:
		tilt_material.set_shader_parameter("tilt", tilt.clamp(-Vector2.ONE, Vector2.ONE))
