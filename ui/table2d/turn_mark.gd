class_name TurnMark
extends Control
## A heavy ink frame ruled round the villager whose turn it is, so whose turn it is reads
## at a glance and in grayscale, not only in the wind-up's swell: a bold hand-ruled line on
## the sheet's outer margin, where nothing is printed, with a notch at its foot pointing
## down into the table. It follows the events as the table plays them: a bid, a play or a
## pass hands the turn on, a round's start gives it to the landlord, a won trick to its
## winner, and when the queue drains it rests where the run waits, on a villager still
## deciding. On the player's own turn no seat is marked: the action column's prompt and its
## live Play say it is theirs. It lies wholly on its seat's sheet and never takes a click.

## The rule's inset from the sheet's edge and its weight, and the notch's width and depth:
## the notch reaches the sheet's edge and no further.
const INSET: float = 4.0
const WEIGHT: float = 4.0
const NOTCH: Vector2 = Vector2(22, 6)
## How far the ruled line strays from straight, at no wear and at the most, in pixels.
const STRAY: Vector2 = Vector2(0.4, 1.4)
const EDGE_POINTS: int = 8
const SEED: int = 6151

## The seat marked now, or Seats.NONE.
var seat: int = Seats.NONE

var _seats: Dictionary[int, SeatPanel] = {}
var _controller: RunController
var _edge: PackedVector2Array = PackedVector2Array()
var _notch: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Follows the events player plays, for the seats shown.
func setup(
	seats: Dictionary[int, SeatPanel], player: EventPlayer, controller: RunController
) -> void:
	_seats = seats
	_controller = controller
	player.played.connect(on_event)
	player.winding.connect(func(event: RunEvent) -> void: mark(event.round_event.seat))
	player.drained.connect(drained)
	# A seat's sheet grows and shrinks with its intel line; the frame keeps to it.
	for panel: SeatPanel in seats.values():
		panel.resized.connect(func() -> void: mark(seat))


## Hands the turn on as one event shows it.
func on_event(event: RunEvent) -> void:
	match event.type:
		RunEvent.Type.BID:
			mark(Seats.next(event.seat))
		RunEvent.Type.SET_STARTED, RunEvent.Type.DEALT, RunEvent.Type.SET_ENDED:
			mark(Seats.NONE)
		RunEvent.Type.ROUND:
			_on_round(event.round_event)


## When the queue has drained, the turn is the player's or a villager still deciding.
func drained() -> void:
	if _controller.awaiting() != RunController.AWAIT_VILLAGER:
		mark(Seats.NONE)
		return
	var view: SeatView = _controller.table.seat_view()
	mark(view.public.seat_to_act if view != null else Seats.NONE)


## Marks a villager's seat, or none for the player's seat or Seats.NONE.
func mark(at: int) -> void:
	seat = at if _seats.has(at) else Seats.NONE
	visible = seat != Seats.NONE
	if not visible:
		return
	var panel: SeatPanel = _seats[seat]
	position = panel.position
	size = panel.size
	queue_redraw()


func _on_round(event: RoundEvent) -> void:
	match event.type:
		RoundEvent.Type.ROUND_STARTED, RoundEvent.Type.TRICK_WON:
			mark(event.seat)
		RoundEvent.Type.PLAYED, RoundEvent.Type.PASSED:
			mark(Seats.next(event.seat))
		RoundEvent.Type.ROUND_ENDED:
			mark(Seats.NONE)


## The ruled frame and its notch in ink worn by the stage, as everything drawn in code is.
func _draw() -> void:
	var worn: float = BowlGrime.wear()
	_shape(Rect2(Vector2.ZERO, size).grow(-INSET - WEIGHT / 2.0), worn)
	var ink: Color = BowlGrime.faded(ScreenKit.INK, worn)
	draw_polyline(_edge, ink, WEIGHT, true)
	draw_line(_edge[_edge.size() - 1], _edge[0], ink, WEIGHT, true)
	draw_colored_polygon(_notch, ink)


## The frame's outline, each side a few points that stray from straight by a fixed seed,
## and the notch hanging from the middle of its foot.
func _shape(frame: Rect2, worn: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var stray: float = lerpf(STRAY.x, STRAY.y, worn)
	var corners: Array[Vector2] = [
		frame.position,
		Vector2(frame.end.x, frame.position.y),
		frame.end,
		Vector2(frame.position.x, frame.end.y),
	]
	_edge.clear()
	for side: int in corners.size():
		var from: Vector2 = corners[side]
		var to: Vector2 = corners[(side + 1) % corners.size()]
		for step: int in EDGE_POINTS:
			var nudge: Vector2 = Vector2(
				rng.randf_range(-stray, stray), rng.randf_range(-stray, stray)
			)
			_edge.append(from.lerp(to, float(step) / EDGE_POINTS) + nudge)
	var middle: float = frame.get_center().x
	_notch.clear()
	_notch.append(Vector2(middle - NOTCH.x / 2.0, frame.end.y))
	_notch.append(Vector2(middle + NOTCH.x / 2.0, frame.end.y))
	_notch.append(Vector2(middle, frame.end.y + NOTCH.y))
