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
## The play area's middle in x, and the seats' width and gap from that middle. The
## Cadre board centers on it between the seats.
const PLAY_CENTER: float = 790.0
const SEAT_WIDTH: float = 380.0
const SEAT_OFFSET: float = 330.0

var _app: DemoApp
var _controller: RunController
var _hand: HandModel
var _pool: CardPool = CardPool.new()
var _player: EventPlayer = EventPlayer.new()
var _seats: Dictionary[int, SeatPanel] = {}
var _plays: Dictionary[int, PlayLane] = {}

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
var _banner: TableBanner = TableBanner.new()
var _replaying: bool = false
var _pause: PauseMenu = PauseMenu.new()
var _atmosphere: TableAtmosphere = TableAtmosphere.new()
var _landlord: int = Seats.NONE


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var rail: ColorRect = ColorRect.new()
	rail.color = RAIL_EDGE
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(rail, Vector2.ZERO, Vector2(1920, 1080))
	var surface: TextureRect = ScreenKit.cover(ScreenKit.ART.table_surface)
	_place(surface, Vector2(0, 72), Vector2(1920, 1008))
	_place(_atmosphere, Vector2(0, 72), Vector2(1920, 1008))
	_atmosphere.name = "Atmosphere"
	# The ledger sits inside its paper, so its margins come from the sheet.
	var ledger_paper: PanelContainer = PanelContainer.new()
	ledger_paper.theme_type_variation = CommonsTheme.SHEET
	ledger_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(ledger_paper, Vector2(1556, 112), Vector2(328, 900))
	ledger_paper.add_child(_ledger)
	_place(_hud, Vector2.ZERO, Vector2(1920, 72))
	_place(_board, Vector2(PLAY_CENTER - 298.0, 128), Vector2(596, 140))
	_place(_hand_view, Vector2(120, 830), Vector2(1080, 220))
	_you.theme_type_variation = CommonsTheme.TITLE
	_you.add_theme_font_size_override("font_size", 28)
	_place(_you, Vector2(120, 750), Vector2(900, 40))
	_place(_actions, Vector2(1230, 780), Vector2(280, 250))
	_place(_need_panel, Vector2(720, 420), Vector2(420, 200))
	_place(_cheat_sheet, Vector2.ZERO, Vector2(1920, 1080))
	_place(_pause, Vector2.ZERO, Vector2(1920, 1080))
	_place(_banner, Vector2(PLAY_CENTER - 380.0, 480), Vector2(760, 0))
	_place(_pool_parent, Vector2(-4000, -4000), Vector2.ZERO)
	_pool_parent.visible = false
	for seat: int in Seats.COUNT:
		_plays[seat] = PlayLane.new()
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
	Settings.changed.connect(_on_setting)
	for lane: PlayLane in _plays.values():
		lane.setup(_pool, _pool_parent, _motion)
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
	_actions.hint.pressed.connect(_on_hint)
	_show_sort()
	_actions.sort.pressed.connect(_toggle_sort)
	_actions.rules.pressed.connect(_cheat_sheet.toggle.bind(_controller))
	_actions.call.pressed.connect(_on_bid.bind(true))
	_actions.decline.pressed.connect(_on_bid.bind(false))
	_need_panel.declared.connect(_on_need)
	_hud.menu.pressed.connect(_open_pause)
	_pause.resumed.connect(func() -> void: _player.set_process(true))
	_pause.to_title.connect(func() -> void: app.show_screen("title", true))
	_pause.quit_game.connect(func() -> void: get_tree().quit())
	# Joining mid-Set replays what already happened silently, without banners.
	_replaying = true
	for event: RunEvent in _controller.set_events():
		_player.push(event)
	_player.flush()
	_replaying = false


## Plays every queued event at once, skipping the pacing.
func skip_events() -> void:
	_player.flush()


## The buttons, for scripted UI tests.
func actions() -> ActionBar:
	return _actions


func need_panel() -> NeedPanel:
	return _need_panel


func _open_pause() -> void:
	_player.set_process(false)
	_pause.open()


## Keyboard shortcuts press the same buttons a click does (P3B.11, in part). Escape
## closes the rules card, or opens the menu.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _pause.visible:
		if _cheat_sheet.visible:
			_cheat_sheet.visible = false
		else:
			_open_pause()
		get_viewport().set_input_as_handled()
		return
	if _pause.visible or _cheat_sheet.visible:
		return
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
## along the top edge of the play area, the same distance from its middle.
func _build_seats() -> void:
	for seat: int in [1, 2]:
		var panel: SeatPanel = SeatPanel.new()
		panel.setup(seat, _app.seat_name(seat), _app.seat_portrait(seat))
		var x: float = (
			PLAY_CENTER + SEAT_OFFSET if seat == 1 else PLAY_CENTER - SEAT_OFFSET - SEAT_WIDTH
		)
		_place(panel, Vector2(x, 112), Vector2(SEAT_WIDTH, 0))
		_seats[seat] = panel


func _on_event(event: RunEvent) -> void:
	Audio.play(AudioEvents.name_for(event))
	match event.type:
		RunEvent.Type.ROUND:
			_on_round_event(event.round_event)
		RunEvent.Type.BID:
			_say(event.seat, tr("table.say.call" if event.value == 1 else "table.say.no_call"))
		RunEvent.Type.PLAY_SCORED:
			_ledger.add_row(_app.seat_name(event.seat), event.amount)
		RunEvent.Type.SET_STARTED, RunEvent.Type.DEALT:
			_new_deal()
		RunEvent.Type.LANDLORD_CHOSEN:
			_landlord = event.seat
			_announce_landlord(event.seat)
	_refresh_status()


func _on_round_event(event: RoundEvent) -> void:
	match event.type:
		RoundEvent.Type.PLAYED:
			_plays[event.seat].show_play(event.cards)
			if event.seat == 0:
				_hand.refresh()
				_hand_view.show_cards()
			if event.pattern.type == Pattern.Type.BOMB or event.pattern.type == Pattern.Type.ROCKET:
				_motion.impact()
				var rocket: bool = event.pattern.type == Pattern.Type.ROCKET
				_announce(tr("banner.rocket" if rocket else "banner.bomb"), ScreenKit.RED)
			_ledger.set_pending(tr("pattern." + _type_name(event.pattern)))
		RoundEvent.Type.PASSED:
			_plays[event.seat].clear()
			_say(event.seat, tr("table.say.pass"))
		RoundEvent.Type.TRICK_WON:
			_sweep_plays(event.seat)
		RoundEvent.Type.ROUND_ENDED:
			var landlord_won: bool = event.seat == _landlord
			var key: String = "banner.landlord_wins" if landlord_won else "banner.peasants_win"
			_announce(tr(key), ScreenKit.INK)
		RoundEvent.Type.ANNOUNCED:
			_say(event.seat, tr("table.say.cards_left").format({"count": event.value}))


## A fresh deal wipes the last round off the table: lanes, ledger, speech, the
## round's banner and the landlord tag, and every villager back to a full hand. Your
## new hand rises in now, not after the bots' first plays.
func _new_deal() -> void:
	_clear_all_plays()
	_ledger.clear_rows()
	_banner.dismiss()
	_landlord = Seats.NONE
	for panel: SeatPanel in _seats.values():
		panel.set_count(Dealer.HAND_SIZE)
		panel.set_role(false, false)
		panel.say("")
	_hand.refresh()
	_hand_view.show_cards()
	_hand_view.deal_in()


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


## The trick's cards slide off toward whoever won it.
func _sweep_plays(winner: int) -> void:
	var toward: Control = _hand_view if winner == 0 else _seats.get(winner, null)
	if toward == null:
		_clear_all_plays()
		return
	var center: Vector2 = toward.global_position + toward.size / 2.0
	for lane: PlayLane in _plays.values():
		lane.sweep(center)


func _on_setting(key: String) -> void:
	if key == "reduced_motion":
		_motion.set_reduced(bool(Settings.value("reduced_motion")))


func _clear_all_plays() -> void:
	for lane: PlayLane in _plays.values():
		lane.clear()


func _announce(text: String, color: Color) -> void:
	if not _replaying:
		_banner.announce(text, color)


func _announce_landlord(seat: int) -> void:
	if seat == 0:
		_announce(tr("banner.landlord_you"), ScreenKit.RED)
	else:
		_announce(tr("banner.landlord_other").format({"name": _app.seat_name(seat)}), ScreenKit.INK)


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
	var state: RunState = _controller.state_copy()
	_hud.show_state(state, _controller.target(), _app.max_rounds())
	_app.update_dread()
	_atmosphere.show_meters(state.famine, state.denunciation)


func _refresh_actions() -> void:
	var my_turn: bool = _player.is_idle() and _controller.awaiting() == RunController.AWAIT_PLAY
	_actions.play.disabled = not (my_turn and _hand.can_play())
	_actions.pass_turn.disabled = not (my_turn and _hand.can_pass())
	if _controller.awaiting() == RunController.AWAIT_BID:
		_actions.reading.text = tr("table.bid_prompt")
		return
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


## Cycles rank, suit and groups, and names the current sort on the button.
func _toggle_sort() -> void:
	var next: int = (_hand_view.sort_mode + 1) % HandView.Sort.size()
	_hand_view.set_sort(next as HandView.Sort)
	_show_sort()


func _show_sort() -> void:
	var mode: String = tr(HandView.SORT_KEYS[_hand_view.sort_mode])
	_actions.sort.text = tr("action.sort_by").format({"mode": mode})
	_actions.sort.tooltip_text = tr("action.sort_tip").format({"mode": mode})


## Selects the play a Medium villager would make, and lights it.
func _on_hint() -> void:
	if _controller.awaiting() != RunController.AWAIT_PLAY:
		return
	var ids: Array[int] = _hand.suggested_ids()
	_hand.select_only(ids)
	_hand_view.show_hint(ids)
	if ids.is_empty():
		_actions.reading.text = tr("hand.hint.pass")


static func _type_name(pattern: Pattern) -> String:
	var name: String = Pattern.Type.keys()[pattern.type]
	return name.to_lower()


func _place(node: Control, at: Vector2, extent: Vector2) -> void:
	add_child(node)
	node.position = at
	node.size = extent
