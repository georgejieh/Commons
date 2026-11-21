class_name KeywordTips
extends CanvasLayer
## The slips that explain keywords on hover, over every screen. Resting the pointer on a
## marked word opens its slip beside the pointer. The slip stays while the pointer is on
## the word, on the slip, or on a slip opened from a word inside it, and for a moment
## after, so the pointer can cross from a word onto its slip and read the words there.
## The engine's own tooltips close the moment the pointer leaves the word, which made a
## keyword inside a tooltip unreachable.

## Seconds the pointer rests on a word before its slip opens, and a slip outlives it.
const DELAY: float = 0.18
const GRACE: float = 0.35
const FADE: float = 0.1
## From the pointer to the slip's corner, the least room at the screen's edge, and how
## far past its paper a slip still counts as under the pointer.
const GAP: Vector2 = Vector2(16, 22)
const EDGE: float = 12.0
const REACH: float = 10.0
const LAYER: int = 90

static var _made: KeywordTips = null

var _slips: Array[KeywordSlip] = []
## The word being rested on, before its slip opens.
var _asked_id: String = ""
var _asked_from: KeywordText = null
var _asked_for: float = 0.0


## The one layer of the running game, made the first time a word is hovered.
static func of(from: Node) -> KeywordTips:
	if _made == null or not is_instance_valid(_made):
		_made = KeywordTips.new()
		from.get_tree().root.add_child(_made)
	return _made


func _init() -> void:
	layer = LAYER
	set_process(false)


## The pointer came to rest on a keyword in text.
func ask(text: KeywordText, keyword_id: String) -> void:
	for slip: KeywordSlip in _slips:
		if slip.source == text and slip.id == keyword_id:
			slip.word_held = true
			return
	_asked_id = keyword_id
	_asked_from = text
	_asked_for = 0.0
	set_process(true)


## The pointer left a keyword in text.
func left(text: KeywordText, keyword_id: String) -> void:
	if _asked_from == text and _asked_id == keyword_id:
		_asked_id = ""
		_asked_from = null
	for slip: KeywordSlip in _slips:
		if slip.source == text and slip.id == keyword_id:
			slip.word_held = false


## The slips open now, outermost first.
func slips() -> Array[KeywordSlip]:
	return _slips


func _process(delta: float) -> void:
	tick(delta, get_viewport().get_mouse_position())


## One step of time with the pointer at mouse: opens a slip asked for long enough, and
## closes those the pointer has left.
func tick(delta: float, mouse: Vector2) -> void:
	if not _asked_id.is_empty():
		_asked_for += delta
		if not is_instance_valid(_asked_from) or not _asked_from.is_visible_in_tree():
			_asked_id = ""
		elif _asked_for >= DELAY:
			_open(_asked_from, _asked_id, mouse)
			_asked_id = ""
	# A slip is held by the pointer on its word, on itself, or by a held slip above it.
	var held: bool = false
	for index: int in range(_slips.size() - 1, -1, -1):
		var slip: KeywordSlip = _slips[index]
		if not is_instance_valid(slip.source) or not slip.source.is_visible_in_tree():
			_close_from(index)
			held = false
			continue
		if not slip.placed and slip.size.y > 0.0:
			_place(slip)
		var under: bool = slip.get_global_rect().grow(REACH).has_point(mouse)
		held = held or slip.word_held or (slip.placed and under)
		slip.idle = 0.0 if held else slip.idle + delta
	while not _slips.is_empty() and _slips.back().idle >= GRACE:
		_close_from(_slips.size() - 1)
	if _slips.is_empty() and _asked_id.is_empty():
		set_process(false)


func _open(text: KeywordText, keyword_id: String, mouse: Vector2) -> void:
	# A word inside an open slip opens the next one; any other starts again.
	var depth: int = 0
	for index: int in _slips.size():
		if _slips[index].is_ancestor_of(text):
			depth = index + 1
	_close_from(depth)
	var slip: KeywordSlip = KeywordSlip.new()
	slip.source = text
	slip.asked_at = mouse
	var chain: PackedStringArray = text.chain.duplicate()
	chain.append(keyword_id)
	slip.explain(keyword_id, chain)
	add_child(slip)
	_slips.append(slip)


## Stands a slip below and right of the pointer, or on the other side where the screen
## ends, once its text has taken its height.
func _place(slip: KeywordSlip) -> void:
	var screen: Rect2 = get_viewport().get_visible_rect().grow(-EDGE)
	var spot: Vector2 = slip.asked_at + GAP
	if spot.x + slip.size.x > screen.end.x:
		spot.x = slip.asked_at.x - GAP.x - slip.size.x
	if spot.y + slip.size.y > screen.end.y:
		spot.y = slip.asked_at.y - GAP.y - slip.size.y
	spot.x = clampf(spot.x, screen.position.x, maxf(screen.position.x, screen.end.x - slip.size.x))
	spot.y = clampf(spot.y, screen.position.y, maxf(screen.position.y, screen.end.y - slip.size.y))
	slip.position = spot
	slip.placed = true
	if UiMotion.reduced():
		slip.modulate.a = 1.0
	else:
		slip.create_tween().tween_property(slip, "modulate:a", 1.0, FADE)


func _close_from(index: int) -> void:
	while _slips.size() > index:
		var slip: KeywordSlip = _slips.pop_back()
		slip.queue_free()
