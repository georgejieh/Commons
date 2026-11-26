class_name HandTremble
extends RefCounted
## Cards tremble in the player's hand as Famine rises: at a small weight one card's print
## shivers by a fraction of a pixel; as the weight grows more of the fan joins in and each
## shakes further, up to DreadEffects.tremble_px. Which cards tremble is fixed by their
## ids, so the same card is the first to go every time. Only the print moves: the offset
## transform is visual only, so a card's rectangle, and where a click on it lands, never
## moves. Nothing trembles under reduced motion.

## Spreads card ids over the share of the fan that trembles; prime, so near ids part.
const SPREAD: int = 7919
const SPREAD_SPAN: int = 101
## The second axis shakes at this many times the first's speed, so the path never closes.
const CROSS_RATE: float = 1.37

var _hand: HandView
var _tuning: DreadEffects
var _clock: float = 0.0
## The views this has moved, so a card that leaves the fan is put back to rest.
var _moved: Array[CardView] = []


func _init(hand: HandView, tuning: DreadEffects) -> void:
	_hand = hand
	_tuning = tuning


## Shakes the fan's trembling cards at weight for one frame. No allocation once the fan
## has been seen.
func step(delta: float, weight: float) -> void:
	_clock += delta
	var views: Array[CardView] = _hand.views()
	_rest_gone(views)
	var reach: float = 0.0 if UiMotion.reduced() else weight * _tuning.tremble_px
	for view: CardView in views:
		var place: float = HandTremble.place_in_line(view.card_id)
		if reach <= 0.0 or place >= weight:
			_rest(view)
			continue
		var phase: float = place * TAU * SPREAD_SPAN
		var turn: float = _clock * TAU * _tuning.tremble_hz
		view.offset_transform_enabled = true
		view.offset_transform_position = (
			Vector2(sin(turn + phase), sin(turn * CROSS_RATE + phase * 2.0)) * reach
		)
		if not _moved.has(view):
			_moved.append(view)


## Puts every card it moved back to rest, as when leaving the table.
func still() -> void:
	for view: CardView in _moved:
		if is_instance_valid(view):
			view.offset_transform_position = Vector2.ZERO
			view.offset_transform_enabled = false
	_moved.clear()


## Where a card stands in the order the fan starts to tremble, 0 to 1: it trembles once
## the weight passes this.
static func place_in_line(card_id: int) -> float:
	return posmod(card_id * SPREAD, SPREAD_SPAN) / float(SPREAD_SPAN)


func _rest(view: CardView) -> void:
	var index: int = _moved.find(view)
	if index < 0:
		return
	view.offset_transform_position = Vector2.ZERO
	view.offset_transform_enabled = false
	_moved.remove_at(index)


## A card that left the fan since the last frame, to the trick or back to the pool.
func _rest_gone(views: Array[CardView]) -> void:
	for index: int in range(_moved.size() - 1, -1, -1):
		var view: CardView = _moved[index]
		if not is_instance_valid(view):
			_moved.remove_at(index)
		elif not views.has(view):
			_rest(view)
