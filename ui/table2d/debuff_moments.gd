class_name DebuffMoments
extends Control
## The debuffs of ADR 0023 acted out at the table, from the run's events, each as a local
## beat (art/STYLE.md, Motion): cards a Levy or Redistribution moves slide to the seat on
## the left, the player's own face up and a villager's face down; a confiscated Cadre's
## card is struck through and stamped on the notice board; a seized plot card is torn in
## two under a cut-in. Glass Walls lays its glass over the hand while it is in force.
## Reduced motion and quiet events, from a replay or a skip, leave only the end state.
## It listens to the table's event player itself, after the table has rendered each
## event.

const FLY_TIME: float = 0.5
const FLY_STAGGER: float = 0.1
const BOT_SCALE: float = 0.6
const BACKS: int = 4

## Over the hand, while the villagers see it.
var glass: GlassPane = GlassPane.new()
var torn: TornCard = TornCard.new()

var _controller: RunController
var _hand: HandModel
var _hand_view: HandView
var _pool: CardPool
var _player: EventPlayer
var _table: TableMoments
var _board: NoticeBoard
var _backs: Array[CardBack] = []
var _fliers: Array[CardView] = []
var _beat: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for _index: int in BACKS:
		var back: CardBack = CardBack.new()
		back.visible = false
		add_child(back)
		_backs.append(back)
	add_child(torn)


## Puts the glass just over the hand, under every sheet and menu, and this layer over the
## whole screen.
func place(screen: Control, hand_view: Control) -> void:
	screen.add_child(glass)
	screen.move_child(glass, hand_view.get_index() + 1)
	glass.position = hand_view.position
	glass.size = hand_view.size
	screen.add_child(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func setup(
	controller: RunController,
	hand: HandModel,
	hand_view: HandView,
	pool: CardPool,
	player: EventPlayer,
	table: TableMoments,
	board: NoticeBoard
) -> void:
	_controller = controller
	_hand = hand
	_hand_view = hand_view
	_pool = pool
	_player = player
	_table = table
	_board = board
	player.played.connect(func(event: RunEvent) -> void: on_event(event, player.flushing))
	player.drained.connect(refresh)
	move_to_front()


## True while a beat is still acting out, for tests.
func is_playing() -> bool:
	return _beat != null and _beat.is_valid() and _beat.is_running()


## Acts out event. quiet keeps the end state and drops the show.
func on_event(event: RunEvent, quiet: bool) -> void:
	match event.type:
		RunEvent.Type.SET_STARTED, RunEvent.Type.DEALT:
			_end_beat()
			glass.set_shown(false, false)
		RunEvent.Type.CARDS_PASSED:
			if quiet or UiMotion.reduced():
				_show_hand()
			else:
				_pass_cards(event)
		RunEvent.Type.CADRE_CONFISCATED:
			_board.show_cadres(_controller)
			_board.strike(event.value, not quiet)
		RunEvent.Type.PLOT_SEIZED:
			if not quiet:
				_seize(event)
		RunEvent.Type.ROUND:
			if event.round_event.type == RoundEvent.Type.KITTY_TAKEN:
				glass.set_shown(_controller.hand_shown(), not quiet)
		RunEvent.Type.DEBUFF_LIFTED:
			refresh()


## Once the queue has drained: the glass and the notice board as the run holds them.
func refresh() -> void:
	glass.set_shown(_controller.hand_shown(), false)


## Cards slide from one seat to the seat on its left: the player's own and those coming to
## the player face up, any passing between the villagers face down.
func _pass_cards(event: RunEvent) -> void:
	var tween: Tween = _start_beat()
	var card_ids: Array[int] = []
	for part: String in event.text.split(",", false):
		card_ids.append(part.to_int())
	var from: int = event.seat
	var to: int = event.value
	var faces: bool = from == 0 or to == 0
	if from == 0:
		_hand_view.hide_cards(card_ids)
	for index: int in card_ids.size():
		var flier: Control = _flier(card_ids[index], faces, index)
		if flier == null:
			continue
		var start: Vector2 = _point(from, card_ids[index]) - flier.size / 2.0
		var end: Vector2 = _point(to, -1) - flier.size / 2.0
		flier.position = start - global_position
		flier.scale = Vector2.ONE * (1.0 if from == 0 or not faces else BOT_SCALE)
		flier.visible = true
		var delay: float = index * FLY_STAGGER
		var fly: PropertyTweener = tween.parallel().tween_property(
			flier, "position", end - global_position, FLY_TIME
		)
		fly.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		var landing: float = 1.0 if to == 0 or not faces else BOT_SCALE
		tween.parallel().tween_property(flier, "scale", Vector2.ONE * landing, FLY_TIME).set_delay(
			delay
		)
	tween.chain().tween_callback(_show_hand)
	tween.tween_callback(_put_away)
	_player.hold(FLY_TIME + card_ids.size() * FLY_STAGGER)


## A face from the pool, or a face-down back for a card the player may not see.
func _flier(card_id: int, face_up: bool, index: int) -> Control:
	if not face_up:
		return _backs[index % _backs.size()]
	var card: CardInstance = _card(card_id)
	var view: CardView = _pool.acquire() if card != null else null
	if view == null:
		return _backs[index % _backs.size()]
	_fliers.append(view)
	view.reparent(self, false)
	view.bind(card)
	view.pivot_offset = view.size / 2.0
	return view


## The seized plot card is torn in two in the middle of the table, under a cut-in.
func _seize(event: RunEvent) -> void:
	var parts: PackedStringArray = event.text.split(",")
	if parts.size() < 2:
		return
	var card: CardInstance = CardInstance.new(
		event.value, parts[0].to_int(), parts[1].to_int(), CardInstance.Origin.PLOT
	)
	var sub: String = tr("callout.plot_seized.sub").format({"card": _controller.card_name(card)})
	var shout: float = _table.callout.shout(
		tr("callout.plot_seized"), Callout.Tier.CUT_IN, TableMoments.LOSS, sub
	)
	var middle: Vector2 = get_viewport_rect().size / 2.0
	_player.hold(maxf(shout, torn.tear(card, middle)))


func _card(card_id: int) -> CardInstance:
	for card: CardInstance in _hand.cards() + _controller.player_cards():
		if card.id() == card_id:
			return card
	return CardInstance.from_deck_id(card_id) if card_id < Deck.SIZE else null


## Where a seat's cards leave from or land: a card in the hand, the hand, or the seat.
func _point(seat: int, card_id: int) -> Vector2:
	if seat == 0:
		if card_id >= 0:
			return _hand_view.card_center(card_id)
		return _hand_view.global_position + _hand_view.size / 2.0
	var panel: SeatPanel = _table.seats()[seat]
	return panel.global_position + panel.size / 2.0


func _show_hand() -> void:
	_hand.refresh()
	_hand_view.show_cards()


func _start_beat() -> Tween:
	_end_beat()
	_beat = create_tween()
	return _beat


func _end_beat() -> void:
	if _beat != null and _beat.is_valid():
		_beat.kill()
	_beat = null
	_put_away()


func _put_away() -> void:
	for back: CardBack in _backs:
		back.visible = false
	for view: CardView in _fliers:
		_pool.release(view)
	_fliers.clear()
