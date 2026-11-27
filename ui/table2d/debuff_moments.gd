class_name DebuffMoments
extends Control
## The debuffs of ADR 0023 acted out at the table, from the run's events, each as a local
## beat (art/STYLE.md, Motion): cards a Levy or Redistribution moves slide to the seat on
## the left, the player's own face up and a villager's face down; a confiscated Cadre's
## card is struck through and stamped on the notice board; a seized plot card is torn in
## two beside a cut-in's words. A slip of paper by the moving cards says which debuff moved
## them and what moved. Glass Walls lays its glass over the hand while it is in force.
## Reduced motion and quiet events, from a replay or a skip, leave only the end state. It
## listens to the table's event player itself, after the table has rendered each event.

## Seconds a card takes to slide to the next seat.
const FLY_TIME: float = 0.5
## Seconds between one card setting off and the next.
const FLY_STAGGER: float = 0.1
## The scale of a card at a villager's seat, which is smaller than at the player's.
const BOT_SCALE: float = 0.6
## How many face-down backs are made, so that many villager's cards can fly at once.
const BACKS: int = 4
## The note's type at Standard.
const NOTE_SIZE: int = 18
## The note's paper padding, in pixels.
const NOTE_PADDING: int = 22
## How far above the moving cards' middle the note stands, in pixels.
const NOTE_LIFT: float = 110.0
## How far a full hand's fan reaches past the hand's box at each end.
const GLASS_REACH: float = 72.0
## Between the end of the line over the hand and the Glass Walls slip beside it.
const STATUS_GAP: float = 16.0
## Room between a seized card and the cut-in's words.
const TORN_GAP: float = 48.0

## Over the hand, while the villagers see it.
var glass: GlassPane = GlassPane.new()
## The seized plot card, torn in two beside the cut-in's words.
var torn: TornCard = TornCard.new()
## What moved and why, while cards are in flight.
var note: PanelContainer = PanelContainer.new()
## Beats acted out so far, cards passed or a card torn, so a beat that has already ended
## can still be counted.
var beats_played: int = 0

var _controller: RunController
var _cards: TableCards
var _hand_view: HandView
var _pool: CardPool
var _player: EventPlayer
var _table: TableMoments
var _board: NoticeBoard
var _backs: Array[CardBack] = []
var _fliers: Array[CardView] = []
var _beat: Tween = null
var _note_text: Label = Label.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var design: CardBackDef = CardBacks.current()
	for _index: int in BACKS:
		var back: CardBack = CardBack.new()
		back.design = design
		back.visible = false
		add_child(back)
		_backs.append(back)
	add_child(torn)
	note.add_theme_stylebox_override("panel", ScreenKit.paper_style(NOTE_PADDING))
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.visible = false
	_note_text.add_theme_font_size_override("font_size", TextSize.px(NOTE_SIZE))
	_note_text.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
	_note_text.add_theme_color_override("font_color", ScreenKit.INK)
	note.add_child(_note_text)
	add_child(note)


## Puts the glass just over the hand, under every sheet and menu, and this layer over the
## whole screen.
func place(screen: Control, hand_view: Control) -> void:
	screen.add_child(glass)
	screen.move_child(glass, hand_view.get_index() + 1)
	# A full hand's fan leans past the hand's own box at both ends: the pane covers it all.
	glass.position = hand_view.position - Vector2(GLASS_REACH, 0)
	glass.size = hand_view.size + Vector2(GLASS_REACH * 2.0, 0)
	screen.add_child(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Wires the moments to the run's controller, the card lookup, the hand, the card pool, the event
## queue, the table's moments and the notice board, and listens to the queue.
func setup(
	controller: RunController,
	cards: TableCards,
	hand_view: HandView,
	pool: CardPool,
	player: EventPlayer,
	table: TableMoments,
	board: NoticeBoard
) -> void:
	_controller = controller
	_cards = cards
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
				_cards.show_hand()
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
				glass.set_shown(_controller.table.hand_shown(), not quiet)
		RunEvent.Type.DEBUFF_LIFTED:
			refresh()


## Keeps the Glass Walls slip clear of the words of the line over the hand, and puts it
## away while a sheet lies over its place.
func clear_slip(line: Label, sheet_up: bool) -> void:
	var face: Font = line.get_theme_font("font")
	var type: int = line.get_theme_font_size("font_size")
	var words: float = face.get_string_size(line.text, HORIZONTAL_ALIGNMENT_LEFT, -1, type).x
	glass.clear_of = line.position.x + words + STATUS_GAP
	glass.covered = sheet_up
	glass.place_slip()


## Once the queue has drained: the glass and the notice board as the run holds them.
func refresh() -> void:
	glass.set_shown(_controller.table.hand_shown(), false)


## Cards slide from one seat to the seat on its left: the player's own and those coming to
## the player face up, any passing between the villagers face down.
func _pass_cards(event: RunEvent) -> void:
	var tween: Tween = _start_beat()
	var card_ids: Array[int] = event.listed()
	var from: int = event.seat
	var to: int = event.value
	var faces: bool = from == Seats.PLAYER or to == Seats.PLAYER
	if from == Seats.PLAYER:
		_hand_view.hide_cards(card_ids)
	for index: int in card_ids.size():
		var flier: Control = _flier(card_ids[index], faces, index)
		if flier == null:
			continue
		var start: Vector2 = _cards.point(from, card_ids[index]) - flier.size / 2.0
		var end: Vector2 = _cards.point(to) - flier.size / 2.0
		flier.position = start - global_position
		flier.scale = Vector2.ONE * (1.0 if from == Seats.PLAYER or not faces else BOT_SCALE)
		flier.visible = true
		var delay: float = index * FLY_STAGGER
		var fly: PropertyTweener = tween.parallel().tween_property(
			flier, "position", end - global_position, FLY_TIME
		)
		fly.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		var landing: float = 1.0 if to == Seats.PLAYER or not faces else BOT_SCALE
		tween.parallel().tween_property(flier, "scale", Vector2.ONE * landing, FLY_TIME).set_delay(
			delay
		)
	_say(event, card_ids)
	tween.chain().tween_callback(_cards.show_hand)
	tween.tween_callback(_put_away)
	_player.hold(FLY_TIME + card_ids.size() * FLY_STAGGER)


## The slip by the moving cards: which debuff moved them, and what moved, in plain words.
func _say(event: RunEvent, card_ids: Array[int]) -> void:
	var names: Dictionary[int, String] = _table.names()
	var text: String = tr("beat.redistribution").format({"count": card_ids.size()})
	if _controller.items.active_debuff_ids().has("levy") and not card_ids.is_empty():
		var card: CardInstance = _cards.card(card_ids[0])
		var shown: String = CardName.of(card) if card != null else ""
		var from_you: bool = event.seat == Seats.PLAYER
		var key: String = "beat.levy.given" if from_you else "beat.levy.taken"
		var other: String = names.get(event.value if from_you else event.seat, "")
		text = tr(key).format({"card": shown, "name": other})
	_note_text.text = text
	note.reset_size()
	var middle: Vector2 = (_cards.point(event.seat) + _cards.point(event.value)) / 2.0
	var at: Vector2 = middle - Vector2(note.size.x / 2.0, NOTE_LIFT) - global_position
	var room: Vector2 = get_viewport_rect().size - note.size
	note.position = at.clamp(Vector2.ZERO, room.max(Vector2.ZERO))
	note.visible = true
	move_child(note, -1)


## The note's words while it shows, for tests.
func note_text() -> String:
	return _note_text.text if note.visible else ""


## A face from the pool, or a face-down back for a card the player may not see.
func _flier(card_id: int, face_up: bool, index: int) -> Control:
	if not face_up:
		return _backs[index % _backs.size()]
	var card: CardInstance = _cards.card(card_id)
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
	var sub: String = tr("callout.plot_seized.sub").format({"card": CardName.of(card)})
	var shout: float = _table.callout.shout(
		tr("callout.plot_seized"), Callout.Tier.CUT_IN, ScreenKit.LOSS, sub
	)
	# The card is held up at the left end of the cloth, clear of the words.
	var words: Rect2 = _table.callout.text_rect()
	var wide: float = torn.shown_size().x
	var middle: Vector2 = Vector2(words.position.x - TORN_GAP - wide / 2.0, words.get_center().y)
	middle.x = maxf(middle.x, wide / 2.0)
	beats_played += 1
	_player.hold(maxf(shout, torn.tear(card, middle)))


func _start_beat() -> Tween:
	_end_beat()
	beats_played += 1
	_beat = create_tween()
	return _beat


func _end_beat() -> void:
	UiMotion.end(_beat)
	_beat = null
	_put_away()


func _put_away() -> void:
	note.visible = false
	for back: CardBack in _backs:
		back.visible = false
	for view: CardView in _fliers:
		_pool.release(view)
	_fliers.clear()
