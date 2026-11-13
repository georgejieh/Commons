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
## The height the need panel and the audit slip center on, between seats and hand.
const SHEET_MIDDLE: float = 520.0
## How far above the hand's middle the player's own stamps land.
const OWN_STAMP_RISE: float = 170.0

var _app: DemoApp
var _controller: RunController
var _hand: HandModel
var _pool: CardPool = CardPool.new()
var _player: EventPlayer = EventPlayer.new()
var _seats: Dictionary[int, SeatPanel] = {}
var _pile: TrickPile = TrickPile.new()

var _hand_view: HandView = HandView.new()
var _hud: TableHud = TableHud.new()
var _ledger: Ledger = Ledger.new()
var _board: NoticeBoard = NoticeBoard.new()
var _debuffs: DebuffStrip = DebuffStrip.new()
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
var _speech: TableSpeech = TableSpeech.new()
var _input: TableInput = TableInput.new()
var _commands: TableCommands = TableCommands.new()
var _dread: DreadLayers = DreadLayers.new()
var _dressing: DreadDressing = DreadDressing.new()
var _surface: TextureRect
var _fx: TableFx = TableFx.new()
var _slip: AuditSlip = AuditSlip.new()
var _moments: TableMoments = TableMoments.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var rail: ColorRect = ColorRect.new()
	rail.color = RAIL_EDGE
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface = ScreenKit.cover(ScreenKit.ART.table_surface)
	# The room fills the screen below the bar, so a 16:10 screen shows more table, not
	# a band of nothing (P3B.11).
	for backdrop: Control in [rail, _surface, _atmosphere]:
		add_child(backdrop)
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		backdrop.offset_top = 0.0 if backdrop == rail else 72.0
	_atmosphere.name = "Atmosphere"
	add_child(_dressing)
	add_child(_dread)
	# The ledger sits inside its paper, so its margins come from the sheet.
	var ledger_paper: PanelContainer = PanelContainer.new()
	ledger_paper.theme_type_variation = CommonsTheme.SHEET
	ledger_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(ledger_paper, Vector2(1556, 112), Vector2(328, 900))
	ledger_paper.add_child(_ledger)
	_place(_hud, Vector2.ZERO, Vector2(1920, 72))
	_place(_board, Vector2(PLAY_CENTER - 298.0, 128), Vector2(596, 140))
	_place(_debuffs, Vector2(PLAY_CENTER - 298.0, 284), Vector2(596, 0))
	_place(_hand_view, Vector2(120, 830), Vector2(1080, 220))
	_you.theme_type_variation = CommonsTheme.TITLE
	_you.add_theme_font_size_override("font_size", 28)
	ScreenKit.paper_outline(_you)
	_place(_you, Vector2(120, 750), Vector2(900, 40))
	_place(_actions, Vector2(1230, 780), Vector2(280, 250))
	_place(_need_panel, Vector2(PLAY_CENTER - 262.0, 360), Vector2(524, 0))
	_place(_slip, Vector2(PLAY_CENTER - 300.0, 400), Vector2(600, 0))
	_need_panel.center = Vector2(PLAY_CENTER, SHEET_MIDDLE)
	_slip.center = Vector2(PLAY_CENTER, SHEET_MIDDLE)
	_place(_fx, Vector2.ZERO, Vector2(1920, 1080))
	_place(_cheat_sheet, Vector2.ZERO, Vector2(1920, 1080))
	_place(_pause, Vector2.ZERO, Vector2(1920, 1080))
	_place(_banner, Vector2(PLAY_CENTER - 380.0, 480), Vector2(760, 0))
	_place(_pool_parent, Vector2(-4000, -4000), Vector2.ZERO)
	_pool_parent.visible = false
	_place(_pile, Vector2(PLAY_CENTER - 460.0, 380), Vector2(920, 300))
	# The need panel, sheets and banner all lie over the pile.
	move_child(_pile, _need_panel.get_index())


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
	_pile.setup(_pool, _pool_parent, _motion)
	_hand_view.motion = _motion
	_build_seats()
	_speech.setup(_seats, app)
	_board.setup(_controller.cadre_slots())
	_need_panel.setup(_controller.base_need(), app.need_cap(), _controller.lie_cost())
	_hand_view.setup(_hand, _pool)
	_commands.setup(_controller, _hand, _hand_view, _actions, _need_panel, _player)
	_actions.rules.pressed.connect(_cheat_sheet.toggle.bind(_controller))
	_player.played.connect(_on_event)
	_player.drained.connect(_on_drained)
	_controller.event_emitted.connect(_player.push)
	var names: Dictionary[int, String] = {
		0: tr("ledger.you"), 1: app.seat_name(1), 2: app.seat_name(2)
	}
	_ledger.setup(names)
	_commands.set_names(names)
	_slip.setup(names)
	_moments.setup(_fx, _slip, _ledger, _seats, _stamp_spot, _pile_center)
	_player.holds = {
		RunEvent.Type.NEED_DECLARED: _player.step, RunEvent.Type.SHARE_PAID: _player.step * 1.6
	}
	_hud.menu.pressed.connect(_open_pause)
	_pause.resumed.connect(func() -> void: _player.set_process(true))
	_pause.to_title.connect(func() -> void: app.show_screen("title", true))
	_pause.quit_game.connect(func() -> void: get_tree().quit())
	_pause.dossier.connect(func() -> void: app.show_screen("dossier"))
	_pause.last_round.connect(func() -> void: app.show_screen("round_summary"))
	_input.setup(_pause, _cheat_sheet, _actions, _hand_view, _controller, _open_pause)
	_setup_dread(app)
	# Joining mid-Set replays what already happened silently, without banners.
	_replaying = true
	for event: RunEvent in _controller.set_events():
		_player.push(event)
	_player.flush()
	_replaying = false


## Plays every queued event at once, skipping the pacing.
func skip_events() -> void:
	_speech.hurry = true
	_player.flush()
	_speech.skip_all()


## The buttons, for scripted UI tests.
func actions() -> ActionBar:
	return _actions


func need_panel() -> NeedPanel:
	return _need_panel


func _open_pause() -> void:
	_player.set_process(false)
	_pause.open()


## Keyboard and gamepad go through TableInput (P3B.11).
func _unhandled_input(event: InputEvent) -> void:
	if _input.handle(event):
		get_viewport().set_input_as_handled()


## Dread reads the run at round boundaries, and starts settled when the table opens.
func _setup_dread(app: DemoApp) -> void:
	var materials: Dictionary[String, ShaderMaterial] = DreadLayers.table_materials(
		app.post.material(), _atmosphere, _dressing
	)
	var panels: Array[SeatPanel] = []
	panels.assign(_seats.values())
	var slots: Dictionary[String, TextureRect] = {"table_surface": _surface}
	_dread.setup(materials, _dressing, panels, slots)
	_dread.refresh(_controller.state_copy(), true)


func _exit_tree() -> void:
	_dread.clear()
	if _controller != null and _controller.event_emitted.is_connected(_player.push):
		_controller.event_emitted.disconnect(_player.push)


## Seat 1 acts after you, so it sits on your right; seat 2 on your left. Both sit
## along the top edge of the play area, the same distance from its middle.
func _build_seats() -> void:
	for seat: int in [1, 2]:
		var panel: SeatPanel = SeatPanel.new()
		panel.setup(seat, _app.seat_name(seat), _app.seat_portrait(seat, SeatPanel.PICTURE_BOX))
		var x: float = (
			PLAY_CENTER + SEAT_OFFSET if seat == 1 else PLAY_CENTER - SEAT_OFFSET - SEAT_WIDTH
		)
		_place(panel, Vector2(x, 112), Vector2(SEAT_WIDTH, 0))
		_seats[seat] = panel


func _on_event(event: RunEvent) -> void:
	# Rejoining replays the Set silently: nothing is said or played twice.
	if not _replaying:
		TableSounds.play(event, _landlord, _controller)
		_speech.on_event(event)
	_moments.on_event(event, _replaying)
	match event.type:
		RunEvent.Type.ROUND:
			_on_round_event(event.round_event)
		RunEvent.Type.PLAY_SCORED:
			_ledger.add_play(event.seat, event.grain, event.rate, event.zeal, event.amount)
		RunEvent.Type.ROUND_SCORED:
			_ledger.set_final(event.seat, event.amount)
			_dread.refresh(_controller.state_copy())
		RunEvent.Type.SET_STARTED, RunEvent.Type.DEALT:
			_new_deal()
			_dread.refresh(_controller.state_copy())
		RunEvent.Type.SET_ENDED, RunEvent.Type.METER_CHANGED:
			_dread.refresh(_controller.state_copy())
		RunEvent.Type.LANDLORD_CHOSEN:
			_landlord = event.seat
			_announce_landlord(event.seat)
			_dread.refresh(_controller.state_copy(), false, event.seat == 0)
	_refresh_status()


func _on_round_event(event: RoundEvent) -> void:
	match event.type:
		RoundEvent.Type.ROUND_STARTED:
			# A kept seat is never bid for again, so the round itself names the landlord.
			_landlord = event.seat
			_ledger.start_round(event.seat)
		RoundEvent.Type.PLAYED:
			_show_play(event)
			if event.seat == 0:
				_hand.refresh()
				_hand_view.show_cards()
			if event.pattern.type == Pattern.Type.BOMB or event.pattern.type == Pattern.Type.ROCKET:
				_motion.impact()
				var rocket: bool = event.pattern.type == Pattern.Type.ROCKET
				_announce(tr("banner.rocket" if rocket else "banner.bomb"), ScreenKit.RED)
			_ledger.set_pending(tr("pattern." + _type_name(event.pattern)))
		RoundEvent.Type.TRICK_WON:
			_pile.sweep(_seat_center(event.seat))
		RoundEvent.Type.ROUND_ENDED:
			var landlord_won: bool = event.seat == _landlord
			var key: String = "banner.landlord_wins" if landlord_won else "banner.peasants_win"
			_announce(tr(key), ScreenKit.INK)


## A fresh deal wipes the last round off the table: lanes, ledger, speech, the
## round's banner and the landlord tag, and every villager back to a full hand. Your
## new hand rises in now, not after the bots' first plays.
func _new_deal() -> void:
	_pile.clear()
	_ledger.clear_rows()
	_banner.dismiss()
	_landlord = Seats.NONE
	_speech.skip_all()
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
	_board.show_cadres(_controller)
	_debuffs.show_debuffs(_controller)
	var awaiting: int = _controller.awaiting()
	_actions.show_bidding(awaiting == RunController.AWAIT_BID)
	_need_panel.visible = awaiting == RunController.AWAIT_NEED
	if awaiting == RunController.AWAIT_NEED:
		var pool: int = _controller.state_copy().commons_pool
		_need_panel.ask(pool, _app.seat_name(3 - _landlord), _controller.audit_chance())
	_hand.refresh()
	_hand_view.show_cards()
	_commands.refresh()
	if awaiting == RunController.AWAIT_SET_OVER or awaiting == RunController.AWAIT_RUN_OVER:
		_app.show_screen("set_summary", true)


## A play flies to the pile from the seat that made it; yours leaves from your hand.
func _show_play(event: RoundEvent) -> void:
	var origins: Array[Vector2] = []
	if event.seat == 0:
		for card: CardInstance in event.cards:
			origins.append(_hand_view.card_center(card.id()))
	_pile.show_play(event.cards, _seat_center(event.seat), origins)


func _seat_center(seat: int) -> Vector2:
	var at: Control = _hand_view if seat == 0 else _seats[seat]
	return at.global_position + at.size / 2.0


## Where a seat's stamps land: over a villager's panel, or just above your hand.
func _stamp_spot(seat: int) -> Vector2:
	var spot: Vector2 = _seat_center(seat)
	return spot - Vector2(0, OWN_STAMP_RISE) if seat == 0 else spot


func _pile_center() -> Vector2:
	return _pile.global_position + _pile.size / 2.0


func _on_setting(key: String) -> void:
	if key == "reduced_motion":
		_motion.set_reduced(bool(Settings.value("reduced_motion")))


func _announce(text: String, color: Color) -> void:
	if not _replaying:
		_banner.announce(text, color)


func _announce_landlord(seat: int) -> void:
	if seat == 0:
		_announce(tr("banner.landlord_you"), ScreenKit.RED)
	else:
		_announce(tr("banner.landlord_other").format({"name": _app.seat_name(seat)}), ScreenKit.INK)


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
		var bid: String = _moments.bid_key(seat)
		if landlord == Seats.NONE and not bid.is_empty():
			panel.set_bid(tr(bid))
	if landlord == Seats.NONE:
		_you.text = tr("table.you.bidding")
	else:
		_you.text = tr("table.you.landlord" if landlord == 0 else "table.you.peasant")


func _refresh_status() -> void:
	var state: RunState = _controller.state_copy()
	_hud.show_state(state, _controller.target(), _app.max_rounds())


static func _type_name(pattern: Pattern) -> String:
	return String(Pattern.Type.keys()[pattern.type]).to_lower()


func _place(node: Control, at: Vector2, extent: Vector2) -> void:
	add_child(node)
	node.position = at
	node.size = extent
