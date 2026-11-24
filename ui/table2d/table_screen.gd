# gdlint: disable=max-file-lines
# Just over 400 lines: only the table's wiring; what it wires lives in classes beside it.
class_name TableScreen
extends Control
## The 2D table (ADR 0017), seen as a play area rather than a whole table: a wooden rail
## frames the screen, the two villagers sit along the top edge with their lanes in front
## of them, the ledger is set into the right rail and your hand runs along the bottom.
## Under the left seat is the Campaign tray, under the right one the rules slip; the
## trick lies between them (ADR 0034, rules 6 to 9).
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
## Half the trick's width about its centre: clear of the Campaign tray at its left.
const PILE_HALF_WIDTH: float = 320.0
const SEAT_WIDTH: float = 380.0
const SEAT_OFFSET: float = 330.0
## The height the need panel and the audit slip center on, between seats and hand.
const SHEET_MIDDLE: float = 520.0
## The action column at Standard: at any text size it keeps its left edge, its foot and
## its width, which is this or the toggles' width at Standard if that is wider.
## It stops 8 px short of the ledger with the widest sort, 330 px at Standard.
const ACTIONS_AT: Rect2 = Rect2(1218, 780, 280, 250)
## The hand's fan: its right end stops short of the action column, so the lean of a full
## hand's last card, which reaches about 98 px past its middle, never runs under the
## buttons.
const HAND_AT: Rect2 = Rect2(120, 830, 1016, 220)
## The room the line over the hand stands in, down to a lifted card's top, and the least
## gap between a sheet and the hand or the bar.
const YOU_ROOM: float = 46.0
const SHEET_GAP: float = 8.0

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
var _moments: TableMoments = TableMoments.new()
var _campaigns: TableCampaigns = TableCampaigns.new()
var _debuff_beats: DebuffMoments = DebuffMoments.new()
var _tutorial: TableTutorial = TableTutorial.new()
var _wild: TableWild = TableWild.new()
var _resize: TableResize = TableResize.new()
var _columns: TableColumns = TableColumns.new()
var _close: RoundClose = RoundClose.new()
var _sit_out: SitOut = SitOut.new()
## Each villager's card count as the events played so far leave it.
var _counts: Dictionary[int, int] = {}


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
	_place(_hand_view, HAND_AT.position, HAND_AT.size)
	_you.theme_type_variation = CommonsTheme.TITLE
	ScreenKit.paper_outline(_you)
	_place(_you, Vector2(120, 750), Vector2(900, 40))
	# The line stands between the notice over it and a lifted card under it: its type fits
	# that room, never under Standard.
	var face: Font = _you.get_theme_font("font")
	var fits: Callable = func(type: int) -> bool: return face.get_height(type) <= YOU_ROOM
	_you.add_theme_font_size_override("font_size", TextSize.fit(28, 28, fits))
	_place(_actions, ACTIONS_AT.position, ACTIONS_AT.size)
	# Held at its foot: a taller prompt grows up into the empty table, never down.
	_actions.hold(ACTIONS_AT)
	# The rules slip under the right seat, as wide as from its edge to the column's.
	var slip_x: float = PLAY_CENTER + SEAT_OFFSET
	_place(_debuffs, Vector2(slip_x, 112), Vector2(_actions.held().end.x - slip_x, 0))
	_place(_need_panel, Vector2(PLAY_CENTER - 262.0, 360), Vector2(524, 0))
	_need_panel.center = Vector2(PLAY_CENTER, SHEET_MIDDLE)
	_need_panel.foot = HAND_AT.position.y - SHEET_GAP
	_need_panel.head = _hud.size.y + SHEET_GAP
	_place(_moments, Vector2.ZERO, Vector2(1920, 1080))
	_pause.at_table = true
	for sheet: Control in [_cheat_sheet, _pause]:
		add_child(sheet)
		sheet.set_deferred("size", Vector2(1920, 1080))
	_place(_pool_parent, Vector2(-4000, -4000), Vector2.ZERO)
	_pool_parent.visible = false
	# Narrower than the table, so the Campaign tray has the room at its left.
	var pile_at: Vector2 = Vector2(PLAY_CENTER - PILE_HALF_WIDTH, 380)
	_place(_pile, pile_at, Vector2(PILE_HALF_WIDTH * 2.0, 300))
	_campaigns.place(self)
	_debuff_beats.place(self, _hand_view)
	_wild.place(self)
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
	_player.motion = _motion
	_motion.setup(self, bool(Settings.value("reduced_motion")))
	Settings.changed.connect(_on_setting)
	_pile.setup(_pool, _pool_parent, _motion)
	_hand_view.motion = _motion
	_build_seats()
	# The moments layer lies over everything, seats included, so a takeover dims it all.
	move_child(_moments, -1)
	_speech.setup(_seats, app)
	_board.setup(_controller.cadre_slots(), _board.size)
	# Wang's slip stands where the board is through the arrival, which holds no Cadre.
	_board.visible = not app.arrival.is_running()
	_need_panel.setup(_controller.base_need(), app.need_cap(), _controller.lie_cost())
	_hand_view.setup(_hand, _pool)
	_commands.setup(_controller, _hand, _hand_view, _actions, _need_panel, _player)
	_commands.open_rules = _cheat_sheet.toggle.bind(_controller)
	_commands.gate = app.arrival.allows
	_tutorial.setup(app, _actions, _hand_view, _need_panel, _cheat_sheet, _pause, _dressing)
	_tutorial.watch(_pile, _player)
	_player.played.connect(_on_event)
	_player.winding.connect(_on_winding)
	_player.drained.connect(_on_drained)
	_controller.event_emitted.connect(_player.push)
	var names: Dictionary[int, String] = {
		0: tr("ledger.you"), 1: app.seat_name(1), 2: app.seat_name(2)
	}
	_ledger.setup(names)
	_commands.set_names(names)
	var faces: Dictionary[int, Texture2D] = {}
	for seat: int in _seats:
		faces[seat] = app.seat_portrait(seat, Vector2.ONE)
	_moments.setup(_ledger, _pile, _motion, _player, _seats, names, faces)
	_moments.hud = _hud
	add_child(_close)
	_close.setup(_player, _pile, _moments, _hand, _hand_view, _seat_center)
	_campaigns.setup(_controller, _hand, _hand_view, _actions, _commands, _player, _moments)
	_campaigns.attach(_pool, _debuffs)
	_columns.setup(_seats, _campaigns.tray, _dressing, _debuffs, _actions, _controller)
	add_child(_sit_out)
	_sit_out.setup(_controller, _actions, _commands, _player, app.arrival.is_running)
	_sit_out.pace_changed.connect(_set_pace)
	_debuff_beats.setup(_controller, _hand, _hand_view, _pool, _player, _moments, _board)
	_set_pace()
	_hud.menu.pressed.connect(_open_pause)
	_pause.resumed.connect(func() -> void: _player.set_process(true))
	# The events wait behind the books' notice until it is acknowledged (ADR 0022).
	app.notice.hold(_player)
	_pause.wire(app)
	_resize.setup(self, app, _pause)
	_input.setup(_pause, _cheat_sheet, _actions, _hand_view, _controller, _open_pause)
	_input.tray = _campaigns.tray
	_wild.setup(_hand_view, _pile, _debuffs, _moments, _player, _commands, _input)
	_setup_dread(app)
	# Joining mid-Set replays what already happened silently, without banners.
	_replaying = true
	_still(true)
	for event: RunEvent in _controller.set_events():
		_player.push(event)
	_player.flush()
	_still(false)
	_replaying = false
	_hud.sync(_controller.state_copy(), _controller.target())


## Plays every queued event at once, skipping the pacing.
func skip_events() -> void:
	_speech.hurry = true
	_still(true)
	_player.flush()
	_still(false)
	_speech.skip_all()


## While the queue is played at once, nothing moves: cards land where they lie and a
## won trick is cleared, not swept, so no tween outlives the catch-up and clears a
## later play.
func _still(on: bool) -> void:
	_motion.set_reduced(on or bool(Settings.value("reduced_motion")))


## The buttons, for scripted UI tests.
func actions() -> ActionBar:
	return _actions


func need_panel() -> NeedPanel:
	return _need_panel


## The hand's sort, kept when the table is built again at a new text size (ADR 0034).
func sort_mode() -> HandView.Sort:
	return _hand_view.sort_mode


func keep_sort(mode: HandView.Sort) -> void:
	_commands.set_sort(mode)


## What the arrival's slip points at on the table (ADR 0026).
func tutorial() -> TableTutorial:
	return _tutorial


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
	# Campaigns first, so a forced pass is tagged as one when its pass arrives.
	_campaigns.on_event(event, _replaying or _player.flushing)
	_moments.on_event(event, _replaying or _player.flushing)
	_wild.on_event(event, _replaying or _player.flushing)
	_resize.on_event(event)
	match event.type:
		RunEvent.Type.ROUND:
			_on_round_event(event.round_event)
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
			_dread.refresh(_controller.state_copy(), false, event.seat == 0)
		RunEvent.Type.CADRE_FIRED:
			if not (_replaying or _player.flushing):
				_board.fired(_controller, event.text, event.value)
	_refresh_status()


func _on_round_event(event: RoundEvent) -> void:
	match event.type:
		RoundEvent.Type.ROUND_STARTED:
			# A kept seat is never bid for again, so the round itself names the landlord.
			_landlord = event.seat
			_ledger.start_round(event.seat)
			_show_roles(event.seat)
		RoundEvent.Type.KITTY_TAKEN:
			_count_cards(event.seat, event.card_ids.size())
		RoundEvent.Type.PLAYED:
			_show_play(event)
			_count_cards(event.seat, -event.cards.size())
			if event.seat == 0:
				_close.own_play(event)
			if event.pattern.type == Pattern.Type.BOMB or event.pattern.type == Pattern.Type.ROCKET:
				_motion.impact()
			_ledger.set_pending(DirectiveSheet.type_name(event.pattern.type))
		RoundEvent.Type.TRICK_WON:
			# A replayed or skipped trick is cleared at once: a sweep still running would
			# clear the plays that come after it.
			if _replaying or _player.flushing:
				_pile.clear()
			else:
				_pile.sweep(_seat_center(event.seat))


## A fresh deal wipes the last round off the table: lanes, ledger, speech, the
## round's banner and the landlord tag, and every villager back to a full hand. Your
## new hand rises in now, not after the bots' first plays.
func _new_deal() -> void:
	_pile.clear()
	_ledger.clear_rows()
	_landlord = Seats.NONE
	_speech.skip_all()
	for seat: int in _seats:
		_counts[seat] = Dealer.HAND_SIZE
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
	var state: RunState = _controller.state_copy()
	_hud.sync(state, _controller.target())
	_dressing.post_notice(DreadDressing.notice_key(state.year, state.set_index + state.round_index))
	_board.show_cadres(_controller)
	# A row of empty slots says nothing: the board stands once a Cadre is held.
	_board.visible = not (_app.arrival.is_running() or state.inventory.cadres.is_empty())
	_debuffs.show_debuffs(_controller)
	var awaiting: int = _controller.awaiting()
	_actions.show_bidding(awaiting == RunController.AWAIT_BID)
	_need_panel.visible = awaiting == RunController.AWAIT_NEED
	_clear_for_sheet()
	if awaiting == RunController.AWAIT_NEED:
		var pool: int = _controller.state_copy().commons_pool
		_need_panel.ask(pool, _app.seat_name(3 - _landlord), _controller.audit_chance())
	_hand.refresh()
	_hand_view.show_cards()
	_campaigns.refresh()
	_commands.refresh()
	_columns.fit()
	_tutorial.settled(awaiting)
	_resize.drained(awaiting)
	if awaiting == RunController.AWAIT_SET_OVER or awaiting == RunController.AWAIT_RUN_OVER:
		_app.show_screen("set_summary", true)
	elif awaiting == RunController.AWAIT_SWAP:
		# The plot swap has its own screen, over the table; it comes back here.
		_app.show_screen("plot_swap")


## A play flies to the pile from the seat that made it; yours leaves from your hand.
func _show_play(event: RoundEvent) -> void:
	var origins: Array[Vector2] = []
	if event.seat == 0:
		for card: CardInstance in event.cards:
			origins.append(_hand_view.card_center(card.id()))
	_pile.show_play(event.cards, _seat_center(event.seat), origins, event.pattern)


func _seat_center(seat: int) -> Vector2:
	var at: Control = _hand_view if seat == 0 else _seats[seat]
	return at.global_position + at.size / 2.0


func _on_setting(key: String) -> void:
	if key == "reduced_motion":
		_motion.set_reduced(bool(Settings.value("reduced_motion")))
	if key == "reduced_motion" or key == "table_pace":
		_set_pace()


## The step between events, and every wait measured in it, at the pace chosen in
## settings: it takes hold at once, mid-round.
func _set_pace() -> void:
	_player.step = _app.motion_step() * _sit_out.pace()
	_player.play_wait = TableMotion.PRESETS.fly_time * _player.step / TableMotion.PRESETS.event_step
	_player.wind = _wind()
	_player.holds = {
		RunEvent.Type.NEED_DECLARED: _player.step, RunEvent.Type.SHARE_PAID: _player.step * 1.6
	}


## The beat a villager's seat is marked for before its cards leave, at the table's pace;
## none under reduced motion.
func _wind() -> float:
	if _motion.reduced:
		return 0.0
	return TableMotion.PRESETS.wind_up * _player.step / TableMotion.PRESETS.event_step


func _on_winding(event: RunEvent) -> void:
	var seat: int = event.round_event.seat
	if not _replaying and _seats.has(seat):
		_motion.wind_up(_seats[seat], _player.wind)


## The seats take their roles as the round starts, and their card counts tick as cards
## are taken and played, without waiting for the queue to drain.
func _show_roles(landlord: int) -> void:
	for seat: int in _seats:
		_seats[seat].set_role(landlord == seat, landlord != seat and landlord != 0)
	_show_you(landlord)


## The line over your hand says your role, from the moment the round starts.
func _show_you(landlord: int) -> void:
	var role: String = "landlord" if landlord == 0 else "peasant"
	_you.text = tr("table.you." + ("bidding" if landlord == Seats.NONE else role))
	_clear_for_sheet()


## The claim sheet lies over the line above the hand, and half a line showing under a
## sheet reads as a fault: the line is put away while the sheet is up, and the Glass
## Walls slip keeps clear of both.
func _clear_for_sheet() -> void:
	_you.visible = not _need_panel.visible
	_debuff_beats.clear_slip(_you, _need_panel.visible)


func _count_cards(seat: int, change: int) -> void:
	if _seats.has(seat):
		_counts[seat] = maxi(int(_counts.get(seat, Dealer.HAND_SIZE)) + change, 0)
		_seats[seat].set_count(_counts[seat])


func _refresh_seats() -> void:
	var view: SeatView = _controller.seat_view()
	var landlord: int = _controller.state_copy().landlord_seat
	for seat: int in _seats:
		var panel: SeatPanel = _seats[seat]
		if view != null:
			panel.set_count(view.public.remaining[seat])
			_counts[seat] = view.public.remaining[seat]
			landlord = view.public.landlord
		var teammate: bool = landlord != Seats.NONE and landlord != seat and landlord != 0
		panel.set_role(landlord == seat, teammate)
		panel.set_intel(IntelText.for_seat(view.info if view != null else null, seat))
		var bid: String = _moments.bid_key(seat)
		if landlord == Seats.NONE and not bid.is_empty():
			panel.set_bid(tr(bid))
	_show_you(landlord)


func _refresh_status() -> void:
	var state: RunState = _controller.state_copy()
	_hud.show_state(state, _app.max_rounds())
	_ledger.show_books(state, _controller.target())


func _place(node: Control, at: Vector2, extent: Vector2) -> void:
	add_child(node)
	node.position = at
	node.size = extent
