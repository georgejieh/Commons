class_name CampaignMoments
extends Control
## A Campaign acted out at the table (ADR 0021), in paper and ink, from the run's events.
## The used leaflet lifts out of the tray and is slapped back down and sealed; then its
## effect plays where it lands: marks are pressed onto the chosen cards, real cards fly
## between a seat and the hand, a folded note slides to the next seat, coupons fly to the
## counter, the debuff strip has its line struck. Overfulfillment and a seizure take the
## whole screen on red cloth. Every node is made once; each beat holds the queue for as
## long as it runs and is taken down at once by the next, so nothing outlives it. Quiet
## events, from a replay or a skip, leave only the end state.

const COUPON: Color = Color("6f9a62")
const SLAP_SCALE: float = 1.35
const LIFT_TIME: float = 0.14
const SLAM_TIME: float = 0.1
const SEAL_HOLD: float = 0.45
const FADE_TIME: float = 0.2
const SEAL_WIDTH: float = 96.0
const PRESS_FROM: float = 3.2
const PRESS_TIME: float = 0.16
const PRESS_STAGGER: float = 0.1
const FLY_TIME: float = 0.42
const FLY_STAGGER: float = 0.08
const NOTE_SIZE: Vector2 = Vector2(54, 38)
const NOTE_TIME: float = 0.45
const TICKETS: int = 5
const TICKET: Vector2 = Vector2(30, 16)
const TICKET_STAGGER: float = 0.06
const MARKS_PER_KIND: int = 3
const THUMP: float = 0.18

var tray: CampaignTray = null

var _controller: RunController
var _hand_view: HandView
var _pool: CardPool
var _player: EventPlayer
var _table: TableMoments
var _seats: Dictionary[int, SeatPanel] = {}
var _names: Dictionary[int, String] = {}
var _debuffs: DebuffStrip
## Finds a card's face by ID, and puts the hand back as the run holds it.
var _card_for: Callable
var _show_hand: Callable
var _leaflet: CampaignLeaflet = CampaignLeaflet.new()
var _seal: InkSeal = InkSeal.new()
var _note: Control = Control.new()
var _tickets: Array[Control] = []
var _marks: Array[CardMark] = []
var _fliers: Array[CardView] = []
var _beat: Tween = null
var _note_tween: Tween = null
var _last_used: String = ""
## The Letter is out at its seat, waiting on the player's play.
var _letter_out: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_leaflet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.size = NOTE_SIZE
	_note.pivot_offset = NOTE_SIZE / 2.0
	_note.draw.connect(_draw_note)
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for _index: int in TICKETS:
		var ticket: Control = Control.new()
		ticket.size = TICKET
		ticket.pivot_offset = TICKET / 2.0
		ticket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ticket.draw.connect(_draw_ticket.bind(ticket))
		_tickets.append(ticket)
	for kind: CardMark.Kind in [CardMark.Kind.STAMP, CardMark.Kind.MODEL]:
		for _index: int in MARKS_PER_KIND:
			_marks.append(CardMark.new(kind))
	var parts: Array[Control] = [_leaflet, _note]
	parts.append_array(_tickets)
	parts.append_array(_marks)
	for part: Control in parts:
		part.visible = false
		add_child(part)
	add_child(_seal)


func setup(
	controller: RunController,
	hand_view: HandView,
	pool: CardPool,
	player: EventPlayer,
	table: TableMoments,
	seats: Dictionary[int, SeatPanel],
	names: Dictionary[int, String],
	debuffs: DebuffStrip,
	card_for: Callable,
	show_hand: Callable
) -> void:
	_controller = controller
	_hand_view = hand_view
	_pool = pool
	_player = player
	_table = table
	_seats = seats
	_names = names
	_debuffs = debuffs
	_card_for = card_for
	_show_hand = show_hand
	_seal.prepare(tr("campaign.sealed"), ScreenKit.RED, SEAL_WIDTH)


## True while a beat is still acting out, for tests.
func is_playing() -> bool:
	return _beat != null and _beat.is_valid() and _beat.is_running()


## True while the Letter waits at its seat, for tests.
func letter_out() -> bool:
	return _letter_out


## Acts out event. quiet keeps the end state and drops the show.
func on_event(event: RunEvent, quiet: bool) -> void:
	match event.type:
		RunEvent.Type.SET_STARTED, RunEvent.Type.DEALT:
			_end_beat()
			_set_letter(false)
		RunEvent.Type.CAMPAIGN_USED:
			_on_used(event, quiet)
		RunEvent.Type.CARDS_MARKED:
			if not quiet:
				_press_marks(_ids(event.text), event.value == 1)
		RunEvent.Type.CARDS_MOVED:
			if not quiet:
				_move_cards(event)
		RunEvent.Type.PASS_FORCED:
			_table.forced_seat = event.seat
			_set_letter(false, not quiet)
		RunEvent.Type.LETTER_LAPSED:
			_set_letter(false, not quiet)
		RunEvent.Type.STAKE_SETTLED:
			if not quiet:
				_settle(event.value == 1, event.amount)
		RunEvent.Type.DEBUFF_LIFTED:
			_debuffs.strike(_controller, not quiet)
		RunEvent.Type.COUPONS_GAINED:
			if not quiet:
				_fly_coupons(event.value)


## The used leaflet leaves its tray place, is slapped down there and sealed, then fades.
func _on_used(event: RunEvent, quiet: bool) -> void:
	_last_used = event.text
	if event.text == "anonymous_letter":
		_set_letter(true, not quiet)
	if quiet or UiMotion.reduced():
		return
	var tween: Tween = _start_beat()
	var slot: int = event.value
	_leaflet.set_compact(tray.compact)
	_leaflet.show_campaign(
		slot,
		event.text,
		_controller.campaign_name(event.text),
		"",
		_controller.is_private_campaign(event.text)
	)
	if slot < tray.campaign_count():
		tray.leaflet(slot).visible = false
	var rest: Vector2 = tray.slot_center(slot) - global_position - _leaflet.size / 2.0
	_leaflet.position = rest
	_leaflet.scale = Vector2.ONE
	_leaflet.modulate.a = 1.0
	_leaflet.visible = true
	move_child(_leaflet, -1)
	tween.tween_property(_leaflet, "scale", Vector2.ONE * SLAP_SCALE, LIFT_TIME)
	tween.tween_property(_leaflet, "scale", Vector2.ONE, SLAM_TIME).set_trans(Tween.TRANS_EXPO)
	tween.tween_callback(_stamp_leaflet)
	tween.tween_interval(SEAL_HOLD)
	tween.tween_property(_leaflet, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(_put_away)
	var seconds: float = LIFT_TIME + SLAM_TIME + SEAL_HOLD + FADE_TIME
	if event.text == "overfulfillment":
		tween.tween_callback(_shout_stake)
		seconds += Callout.seconds_for(Callout.Tier.TAKEOVER)
	_player.hold(seconds)


func _stamp_leaflet() -> void:
	_table.bump(THUMP)
	_seal.position = _leaflet.position + _leaflet.size / 2.0 - _seal.size / 2.0
	move_child(_seal, -1)
	_seal.press()


func _shout_stake() -> void:
	var times: int = _controller.campaign_parameter("overfulfillment", "win_times")
	var sub: String = tr("callout.overfulfil.sub").format({"times": times})
	_table.callout.shout(tr("callout.overfulfil"), Callout.Tier.TAKEOVER, ScreenKit.RED, sub)
	_table.bump(TableMoments.TAKEOVER_SHAKE)


## Marks drop onto the chosen cards like a seal pressed from above, one after another,
## then the hand shows them as its own.
func _press_marks(card_ids: Array[int], model: bool) -> void:
	if UiMotion.reduced():
		_show_hand.call()
		return
	var tween: Tween = _start_beat()
	var kind: CardMark.Kind = CardMark.Kind.MODEL if model else CardMark.Kind.STAMP
	var spot: Vector2 = CardView.ROSETTE_AT if model else CardView.CHOP_AT
	var used: int = 0
	for mark: CardMark in _marks:
		if mark.kind != kind or used >= card_ids.size():
			continue
		var at: Vector2 = _hand_view.card_at(card_ids[used], spot) - global_position
		mark.position = at
		mark.pivot_offset = mark.size / 2.0
		mark.scale = Vector2.ONE * PRESS_FROM
		mark.modulate.a = 0.0
		mark.visible = true
		mark.queue_redraw()
		tween.parallel().tween_property(mark, "scale", Vector2.ONE, PRESS_TIME).set_delay(
			used * PRESS_STAGGER
		)
		tween.parallel().tween_property(mark, "modulate:a", 1.0, PRESS_TIME * 0.5).set_delay(
			used * PRESS_STAGGER
		)
		used += 1
	tween.chain().tween_interval(PRESS_TIME)
	tween.tween_callback(_show_hand)
	tween.tween_callback(_put_away)
	_player.hold(PRESS_TIME * 2.0 + used * PRESS_STAGGER)


## Real cards fly between the hand and a seat. A seizure takes the screen first.
func _move_cards(event: RunEvent) -> void:
	var card_ids: Array[int] = _ids(event.text)
	var seizing: bool = _last_used == "seizure_notice"
	if UiMotion.reduced():
		if event.value == 0:
			_show_hand.call()
		return
	var tween: Tween = _start_beat()
	var wait: float = 0.0
	if seizing and event.seat == 0:
		var name: String = _names.get(event.value, "")
		var sub: String = tr("callout.seizure.sub").format({"name": name})
		wait = _table.callout.shout(
			tr("callout.seizure"), Callout.Tier.TAKEOVER, ScreenKit.RED, sub
		)
		_table.bump(TableMoments.TAKEOVER_SHAKE)
		tween.tween_interval(wait)
	if event.seat == 0:
		_hand_view.hide_cards(card_ids)
	for index: int in card_ids.size():
		var view: CardView = _pool.acquire()
		if view == null:
			break
		_fliers.append(view)
		view.reparent(self, false)
		view.bind(_card_for.call(card_ids[index]))
		var from: Vector2 = _point(event.seat, card_ids[index]) - view.size / 2.0
		var to: Vector2 = _point(event.value, -1) - view.size / 2.0
		view.position = from - global_position
		view.scale = Vector2.ONE * (1.0 if event.seat == 0 else 0.6)
		var delay: float = wait + index * FLY_STAGGER
		var fly: PropertyTweener = tween.parallel().tween_property(
			view, "position", to - global_position, FLY_TIME
		)
		fly.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var shrink: float = 0.6 if event.value != 0 else 1.0
		tween.parallel().tween_property(view, "scale", Vector2.ONE * shrink, FLY_TIME).set_delay(
			delay
		)
	tween.chain().tween_callback(_show_hand)
	tween.tween_callback(_put_away)
	_player.hold(wait + FLY_TIME + card_ids.size() * FLY_STAGGER)


## The bank settled: doubled is the plan overfulfilled, a loss voids it.
func _settle(won: bool, amount: float) -> void:
	var word: String = tr("callout.stake.won" if won else "callout.stake.lost")
	var sub: String = tr("callout.stake.won.sub" if won else "callout.stake.lost.sub")
	sub = sub.format({"amount": Strings.score(amount)})
	var cloth: Color = ScreenKit.RED if won else TableMoments.LOSS
	_player.hold(_table.callout.shout(word, Callout.Tier.CUT_IN, cloth, sub))


## Coupons fly from the tray to the coupon counter, one ticket after another.
func _fly_coupons(count: int) -> void:
	if UiMotion.reduced() or _table.hud == null:
		return
	var tween: Tween = _start_beat()
	var to: Vector2 = _table.hud.coupons.global_position + _table.hud.coupons.size / 2.0
	var from: Vector2 = tray.global_position + tray.size / 2.0
	var shown: int = mini(count, TICKETS)
	for index: int in shown:
		var ticket: Control = _tickets[index]
		ticket.position = from - global_position - TICKET / 2.0
		ticket.rotation = 0.0
		ticket.visible = true
		ticket.queue_redraw()
		var delay: float = index * TICKET_STAGGER
		var fly: PropertyTweener = tween.parallel().tween_property(
			ticket, "position", to - global_position - TICKET / 2.0, FLY_TIME
		)
		fly.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(ticket, "rotation", TAU * 0.5, FLY_TIME).set_delay(delay)
	tween.chain().tween_callback(_put_away)
	tween.tween_callback(UiMotion.pulse.bind(_table.hud.coupons))
	_player.hold(FLY_TIME + shown * TICKET_STAGGER)


## The Letter goes out to the next seat, or is taken back from it.
func _set_letter(out: bool, animate: bool = false) -> void:
	_letter_out = out
	if _note_tween != null and _note_tween.is_valid():
		_note_tween.kill()
	_note_tween = null
	var seat: SeatPanel = _seats.get(1)
	if seat == null:
		_note.visible = false
		return
	var rest: Vector2 = seat.global_position + Vector2(seat.size.x - NOTE_SIZE.x - 8, -10)
	rest -= global_position
	if not animate or UiMotion.reduced():
		_note.visible = out
		_note.position = rest
		_note.modulate.a = 1.0
		_note.rotation = 0.12
		return
	_note.visible = true
	_note_tween = create_tween()
	if out:
		_note.position = tray.global_position - global_position
		_note.modulate.a = 1.0
		_note_tween.tween_property(_note, "position", rest, NOTE_TIME).set_trans(Tween.TRANS_CUBIC)
		_note_tween.parallel().tween_property(_note, "rotation", 0.12, NOTE_TIME)
	else:
		_note_tween.tween_property(_note, "rotation", -0.4, NOTE_TIME * 0.5)
		_note_tween.parallel().tween_property(_note, "modulate:a", 0.0, NOTE_TIME * 0.5)
		_note_tween.tween_callback(_note.hide)


## Takes the beat under way down at once, leaving its end state, and starts a new one.
func _start_beat() -> Tween:
	_end_beat()
	_beat = create_tween()
	return _beat


func _end_beat() -> void:
	if _beat != null and _beat.is_valid():
		_beat.kill()
	_beat = null
	_put_away()


## Hides every part of a beat and gives its cards back to the pool.
func _put_away() -> void:
	_leaflet.visible = false
	_seal.visible = false
	for part: Control in _tickets + _marks:
		part.visible = false
	for view: CardView in _fliers:
		_pool.release(view)
	_fliers.clear()


## Where a seat's cards come from or go: a card in the hand, the hand, or the seat.
func _point(seat: int, card_id: int) -> Vector2:
	if seat == 0:
		if card_id >= 0:
			return _hand_view.card_center(card_id)
		return _hand_view.global_position + _hand_view.size / 2.0
	var panel: SeatPanel = _seats[seat]
	return panel.global_position + panel.size / 2.0


func _draw_note() -> void:
	CampaignPaper.note(_note, Rect2(Vector2.ZERO, NOTE_SIZE), BowlGrime.wear())


func _draw_ticket(ticket: Control) -> void:
	var worn: float = BowlGrime.wear()
	var rect: Rect2 = Rect2(Vector2.ZERO, TICKET)
	ticket.draw_rect(rect, CampaignPaper.ink(COUPON, worn))
	ticket.draw_rect(rect.grow(-3.0), Color(CampaignPaper.paper(worn), 0.5), false, 1.0)


static func _ids(text: String) -> Array[int]:
	var ids: Array[int] = []
	for part: String in text.split(",", false):
		ids.append(part.to_int())
	return ids
