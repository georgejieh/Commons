class_name TableScreen
extends Control
## The 2D table (ADR 0017), seen as a play area rather than a whole table: a wooden rail
## frames the screen, the two villagers sit along the top edge with their lanes in front
## of them, the ledger is set into the right rail and your hand runs along the bottom.
## It renders the run's events one step apart and sends commands; it never changes the
## run.

const PAPER: Color = Color("efe3c8")
const RAIL: Color = Color("6b4a2e")
const RAIL_EDGE: Color = Color("3e2a19")
const SURFACE: Color = Color("e9dcbc")
const INK: Color = Color("1e1a16")
const RED: Color = Color("9e1b16")
const PLAY_SCALE: float = 0.7

var _app: DemoApp
var _controller: RunController
var _hand: HandModel
var _pool: CardPool = CardPool.new()
var _player: EventPlayer = EventPlayer.new()
var _seats: Dictionary[int, SeatPanel] = {}
var _plays: Dictionary[int, HBoxContainer] = {}
var _play_views: Dictionary[int, Array] = {}

var _hand_view: HandView = HandView.new()
var _hud: TableHud = TableHud.new()
var _ledger: Ledger = Ledger.new()
var _board: NoticeBoard = NoticeBoard.new()
var _actions: ActionBar = ActionBar.new()
var _need_panel: NeedPanel = NeedPanel.new()
var _cheat_sheet: CheatSheet = CheatSheet.new()
var _pool_parent: Control = Control.new()
var _you: Label = Label.new()
var _motion: TableMotion = TableMotion.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_place(_backdrop(RAIL_EDGE), Vector2.ZERO, Vector2(1920, 1080))
	_place(_backdrop(RAIL), Vector2(8, 80), Vector2(1904, 992))
	_place(_backdrop(SURFACE), Vector2(48, 112), Vector2(1480, 928))
	_place(_backdrop(PAPER), Vector2(1560, 112), Vector2(320, 928))
	_place(_hud, Vector2.ZERO, Vector2(1920, 72))
	_place(_board, Vector2(560, 128), Vector2(600, 140))
	_place(_ledger, Vector2(1576, 128), Vector2(290, 640))
	_place(_hand_view, Vector2(120, 830), Vector2(1080, 220))
	_you.add_theme_font_size_override("font_size", 26)
	_you.add_theme_color_override("font_color", INK)
	_place(_you, Vector2(120, 750), Vector2(900, 40))
	_place(_actions, Vector2(1230, 780), Vector2(280, 250))
	_place(_need_panel, Vector2(720, 420), Vector2(420, 200))
	_place(_cheat_sheet, Vector2(560, 120), Vector2(680, 760))
	_place(_pool_parent, Vector2(-4000, -4000), Vector2.ZERO)
	_pool_parent.visible = false
	for seat: int in Seats.COUNT:
		var play_area: HBoxContainer = HBoxContainer.new()
		play_area.add_theme_constant_override("separation", -30)
		_plays[seat] = play_area
		_play_views[seat] = []
	_place(_plays[0], Vector2(520, 560), Vector2(560, 130))
	_place(_plays[1], Vector2(900, 360), Vector2(520, 130))
	_place(_plays[2], Vector2(140, 360), Vector2(520, 130))


func open(app: DemoApp) -> void:
	_app = app
	_controller = app.controller
	_hand = app.hand
	_pool.fill(_pool_parent)
	add_child(_pool)
	add_child(_player)
	add_child(_motion)
	_player.step = app.motion_step()
	_player.motion = _motion
	_motion.setup(self, bool(Settings.value("reduced_motion")))
	_hand_view.motion = _motion
	_build_seats()
	_board.setup(_controller.cadre_slots())
	_need_panel.setup(_controller.base_need(), app.need_cap())
	_hand_view.setup(_hand, _pool)
	_hand.changed.connect(_refresh_actions)
	_player.played.connect(_on_event)
	_player.drained.connect(_on_drained)
	_controller.event_emitted.connect(_player.push)
	_player.queued.connect(_refresh_actions)
	_actions.play.pressed.connect(_on_play)
	_actions.pass_turn.pressed.connect(_on_pass)
	_actions.hint.toggled.connect(_hand_view.set_hint)
	_actions.sort.pressed.connect(_toggle_sort)
	_actions.rules.pressed.connect(_cheat_sheet.toggle.bind(_controller))
	_actions.call.pressed.connect(_on_bid.bind(true))
	_actions.decline.pressed.connect(_on_bid.bind(false))
	_need_panel.declared.connect(_on_need)
	for event: RunEvent in _controller.set_events():
		_player.push(event)
	_player.flush()


## Plays every queued event at once, skipping the pacing.
func skip_events() -> void:
	_player.flush()


## The buttons, for scripted UI tests.
func actions() -> ActionBar:
	return _actions


func need_panel() -> NeedPanel:
	return _need_panel


## Keyboard shortcuts press the same buttons a click does (P3B.11, in part).
func _unhandled_input(event: InputEvent) -> void:
	var shortcuts: Dictionary[String, Button] = {
		"commons_play": _actions.call if _actions.call.visible else _actions.play,
		"commons_pass": _actions.decline if _actions.decline.visible else _actions.pass_turn,
		"commons_hint": _actions.hint,
		"commons_sort": _actions.sort,
		"commons_rules": _actions.rules,
	}
	for action: String in shortcuts:
		var button: Button = shortcuts[action]
		if event.is_action_pressed(action) and button.is_visible_in_tree() and not button.disabled:
			if button.toggle_mode:
				button.button_pressed = not button.button_pressed
			else:
				button.pressed.emit()
			get_viewport().set_input_as_handled()
			return


func _exit_tree() -> void:
	if _controller != null and _controller.event_emitted.is_connected(_player.push):
		_controller.event_emitted.disconnect(_player.push)


## Seat 1 acts after you, so it sits on your right; seat 2 on your left. Both sit
## along the top edge of the play area, facing you.
func _build_seats() -> void:
	for seat: int in [1, 2]:
		var panel: SeatPanel = SeatPanel.new()
		panel.setup(seat, _app.seat_name(seat), _app.seat_portrait(seat))
		var x: float = 1180.0 if seat == 1 else 72.0
		_place(panel, Vector2(x, 128), Vector2(340, 200))
		_seats[seat] = panel


func _on_event(event: RunEvent) -> void:
	Audio.play(AudioEvents.name_for(event))
	match event.type:
		RunEvent.Type.ROUND:
			_on_round_event(event.round_event)
		RunEvent.Type.BID:
			_say(event.seat, tr("table.say.call" if event.value == 1 else "table.say.pass"))
		RunEvent.Type.PLAY_SCORED:
			_ledger.add_row(_app.seat_name(event.seat), event.amount)
		RunEvent.Type.SET_STARTED, RunEvent.Type.DEALT:
			_clear_all_plays()
			_ledger.clear_rows()
	_refresh_status()


func _on_round_event(event: RoundEvent) -> void:
	match event.type:
		RoundEvent.Type.PLAYED:
			_show_play(event.seat, event.cards)
			if event.seat == 0:
				_hand.refresh()
				_hand_view.show_cards()
			if event.pattern.type == Pattern.Type.BOMB or event.pattern.type == Pattern.Type.ROCKET:
				_motion.impact()
			_ledger.set_pending(tr("pattern." + _type_name(event.pattern)))
		RoundEvent.Type.PASSED:
			_clear_play(event.seat)
			_say(event.seat, tr("table.say.pass"))
		RoundEvent.Type.TRICK_WON:
			_clear_all_plays()
		RoundEvent.Type.ANNOUNCED:
			_say(event.seat, tr("table.say.cards_left").format({"count": event.value}))


func _on_drained() -> void:
	_refresh_seats()
	_refresh_status()
	_board.show_cadres(_controller.state_copy().inventory.cadres)
	var awaiting: int = _controller.awaiting()
	_actions.show_bidding(awaiting == RunController.AWAIT_BID)
	_need_panel.visible = awaiting == RunController.AWAIT_NEED
	if awaiting == RunController.AWAIT_NEED:
		_need_panel.ask()
	_hand.refresh()
	_hand_view.show_cards()
	_refresh_actions()
	if awaiting == RunController.AWAIT_SET_OVER or awaiting == RunController.AWAIT_RUN_OVER:
		_app.show_screen("set_summary", true)


func _show_play(seat: int, cards: Array[CardInstance]) -> void:
	_clear_play(seat)
	for card: CardInstance in cards:
		var view: CardView = _pool.acquire()
		if view == null:
			return
		view.reparent(_plays[seat], false)
		view.position = Vector2.ZERO
		view.rotation = 0.0
		view.bind(card)
		view.scale = Vector2(PLAY_SCALE, PLAY_SCALE)
		view.custom_minimum_size = view.size * PLAY_SCALE
		_play_views[seat].append(view)


func _clear_play(seat: int) -> void:
	for view: CardView in _play_views[seat]:
		view.scale = Vector2.ONE
		view.reparent(_pool_parent, false)
		_pool.release(view)
	_play_views[seat].clear()


func _clear_all_plays() -> void:
	for seat: int in _play_views:
		_clear_play(seat)


func _say(seat: int, text: String) -> void:
	if _seats.has(seat):
		_seats[seat].say(text)


func _refresh_seats() -> void:
	var view: SeatView = _controller.seat_view()
	var landlord: int = _controller.state_copy().landlord_seat
	for seat: int in _seats:
		var panel: SeatPanel = _seats[seat]
		if view != null:
			panel.set_count(view.public.remaining[seat])
			landlord = view.public.landlord
		var teammate: bool = landlord != Seats.NONE and landlord != seat and landlord != 0
		panel.set_role(landlord == seat, teammate)
	if landlord == Seats.NONE:
		_you.text = tr("table.you.bidding")
	else:
		_you.text = tr("table.you.landlord" if landlord == 0 else "table.you.peasant")


func _refresh_status() -> void:
	_hud.show_state(_controller.state_copy(), _controller.target(), _app.max_rounds())


func _refresh_actions() -> void:
	var my_turn: bool = _player.is_idle() and _controller.awaiting() == RunController.AWAIT_PLAY
	_actions.play.disabled = not (my_turn and _hand.can_play())
	_actions.pass_turn.disabled = not (my_turn and _hand.can_pass())
	var text: String = tr(_hand.label_key())
	if _hand.can_play() or _hand.projected_score() > 0.0:
		text += "  ·  " + Strings.score(_hand.projected_score())
	_actions.reading.text = text


## Every command fills the event queue, so the buttons go off until it drains.
func _on_play() -> void:
	if _controller.play(_hand.selected_ids()) == RunController.OK:
		_hand.clear()
	_refresh_actions()


func _on_pass() -> void:
	_controller.pass_turn()
	_hand.clear()
	_refresh_actions()


func _on_bid(claim: bool) -> void:
	_actions.show_bidding(false)
	_controller.bid(claim)
	_refresh_actions()


func _on_need(need: int) -> void:
	_need_panel.visible = false
	_controller.declare_need(need)
	_refresh_actions()


func _toggle_sort() -> void:
	var grouped: bool = _hand_view.sort_mode == HandView.Sort.RANK
	_hand_view.set_sort(HandView.Sort.GROUPS if grouped else HandView.Sort.RANK)


static func _type_name(pattern: Pattern) -> String:
	var name: String = Pattern.Type.keys()[pattern.type]
	return name.to_lower()


func _place(node: Control, at: Vector2, extent: Vector2) -> void:
	add_child(node)
	node.position = at
	node.size = extent


static func _backdrop(color: Color) -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
