# gdlint: disable=max-file-lines
# Over 400 lines: the one node that holds every piece of the table, each a documented part
# tests and the walks read, wires each to the run and the others, and hands each event to
# the pieces that show it; each piece's own work lives in its class beside this one.
class_name TableScreen
extends Control
## The 2D table (ADR 0017), seen as a play area rather than a whole table: a wooden rail
## frames the screen, the two villagers sit along the top edge with their lanes in front of
## them, the ledger is set into the right rail and your hand runs along the bottom. Under
## the left seat is the Campaign tray, under the right one the rules slip; the trick lies
## between them (ADR 0034, rules 6 to 10). It renders the run's events one step apart and
## sends commands; it never changes the run.

const RAIL_EDGE: Color = Color("3e2a19")
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

## Every card view the table draws, made once and reused.
var pool: CardPool = CardPool.new()
## Plays the run's events one step apart.
var player: EventPlayer = EventPlayer.new()
## Each villager's panel by seat: portrait, name, role, cards left and speech.
var seats: Dictionary[int, SeatPanel] = {}
## The bar across the top: where the run is, the Quota and the meters.
var hud: TableHud = TableHud.new()
## The trick in the middle of the table.
var pile: TrickPile = TrickPile.new()
## The player's hand, fanned along the bottom.
var hand_view: HandView = HandView.new()
## The round's scoreboard, set into the right rail.
var ledger: Ledger = Ledger.new()
## The player's Cadres, pinned between the seats once one is held.
var board: NoticeBoard = NoticeBoard.new()
## The rules slip under the right seat: the rules in force this round.
var debuffs: DebuffStrip = DebuffStrip.new()
## The column of the player's buttons: bid, play, pass, hint and sort.
var actions: ActionBar = ActionBar.new()
## The sheet the player declares their need on.
var need_panel: NeedPanel = NeedPanel.new()
## The rules card, every hand type with its Rate.
var cheat_sheet: CheatSheet = CheatSheet.new()
## The line over the hand that says the player's role.
var you: Label = Label.new()
## How the table's pieces move, and whether they move at all.
var motion: TableMotion = TableMotion.new()
## The menu over the table.
var pause: PauseMenu = PauseMenu.new()
## The deck sheet over the table, opened from the menu or its key.
var deck: DeckSheet = null
## What the villagers say at the table.
var speech: TableSpeech = TableSpeech.new()
## The board's dread drawn over the room.
var dread: DreadLayers = DreadLayers.new()
## The dread's set dressing: notices and marks on the room.
var dressing: DreadDressing = DreadDressing.new()
## The table's surface, which the corruption stages wear.
var surface: TextureRect
## The beats, banners and tallies that act the run out over the play.
var moments: TableMoments = TableMoments.new()
## The player's Campaigns: the tray and its moments.
var campaigns: TableCampaigns = TableCampaigns.new()
## The debuffs acted out at the table.
var debuff_beats: DebuffMoments = DebuffMoments.new()
## What a deal shows before the bid.
var deal_beats: DealMoments = DealMoments.new()
## What the arrival's slip points at on the table (ADR 0026).
var tutorial: TableTutorial = TableTutorial.new()
## The wild ranks at the table: the call-out, the strip and the picker.
var wild: TableWild = TableWild.new()
## The two side columns under the seats, laid out to fit (ADR 0034).
var columns: TableColumns = TableColumns.new()
## Sitting out a trick, and its pace.
var sit_out: SitOut = SitOut.new()
## The private-plot swap, a sheet over the table (ADR 0038).
var swap_sheet: PlotSwapSheet = PlotSwapSheet.new()
## The frame round the villager whose turn it is.
var turn: TurnMark = TurnMark.new()
var _app: App
var _controller: RunController
var _hand: HandModel
var _pool_parent: Control = Control.new()
var _replaying: bool = false
var _atmosphere: TableAtmosphere = TableAtmosphere.new()
var _landlord: int = Seats.NONE
var _input: TableInput = TableInput.new()
var _commands: TableCommands = TableCommands.new()
var _resize: TableResize = TableResize.new()
var _close: RoundClose = RoundClose.new()
var _kept: KeptSeatCall = KeptSeatCall.new()
var _cards: TableCards
## Each villager's card count as the events played so far leave it.
var _counts: Dictionary[int, int] = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_lay_room()
	_lay_papers()
	_lay_over()


## The rail, the table's surface and the room's dark, and the dread drawn over them.
func _lay_room() -> void:
	var rail: ColorRect = ColorRect.new()
	rail.color = RAIL_EDGE
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface = ScreenKit.cover(ScreenKit.ART.table_surface)
	# The room fills the screen below the bar, so a 16:10 screen shows more table, not
	# a band of nothing.
	for backdrop: Control in [rail, surface, _atmosphere]:
		add_child(backdrop)
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		backdrop.offset_top = 0.0 if backdrop == rail else 72.0
	_atmosphere.name = "Atmosphere"
	add_child(dressing)
	add_child(dread)


## The bar, the ledger, the board, the hand, the line over it, the buttons, the rules slip
## and the claim sheet, each where the table keeps it.
func _lay_papers() -> void:
	# The ledger sits inside its paper, so its margins come from the sheet.
	var ledger_paper: PanelContainer = PanelContainer.new()
	ledger_paper.theme_type_variation = CommonsTheme.SHEET
	ledger_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(ledger_paper, Vector2(1556, 112), Vector2(328, 900))
	ledger_paper.add_child(ledger)
	_place(hud, Vector2.ZERO, Vector2(1920, 72))
	_place(board, Vector2(PLAY_CENTER - 298.0, 128), Vector2(596, 140))
	_place(hand_view, HAND_AT.position, HAND_AT.size)
	you.theme_type_variation = CommonsTheme.TITLE
	ScreenKit.paper_outline(you)
	_place(you, Vector2(120, 750), Vector2(900, 40))
	# The line stands between the notice over it and a lifted card under it: its type fits
	# that room, never under Standard.
	var face: Font = you.get_theme_font("font")
	var fits: Callable = func(type: int) -> bool: return face.get_height(type) <= YOU_ROOM
	you.add_theme_font_size_override("font_size", TextSize.fit(28, 28, fits))
	_place(actions, ACTIONS_AT.position, ACTIONS_AT.size)
	# Held at its foot: a taller prompt grows up into the empty table, never down.
	actions.hold(ACTIONS_AT)
	# The rules slip under the right seat, as wide as from its edge to the column's.
	var slip_x: float = PLAY_CENTER + SEAT_OFFSET
	_place(debuffs, Vector2(slip_x, 112), Vector2(actions.held().end.x - slip_x, 0))
	_place(need_panel, Vector2(PLAY_CENTER - 262.0, 360), Vector2(524, 0))
	need_panel.center = Vector2(PLAY_CENTER, SHEET_MIDDLE)
	need_panel.foot = HAND_AT.position.y - SHEET_GAP
	need_panel.head = hud.size.y + SHEET_GAP


## What lies over the play: the moments, the sheets and the menu, the trick and the pieces
## placed around it.
func _lay_over() -> void:
	_place(moments, Vector2.ZERO, Vector2(1920, 1080))
	pause.at_table = true
	add_child(swap_sheet)
	for sheet: Control in [cheat_sheet, pause]:
		add_child(sheet)
		sheet.set_deferred("size", Vector2(1920, 1080))
	_place(_pool_parent, Vector2(-4000, -4000), Vector2.ZERO)
	_pool_parent.visible = false
	# Narrower than the table, so the Campaign tray has the room at its left.
	var pile_at: Vector2 = Vector2(PLAY_CENTER - PILE_HALF_WIDTH, 380)
	_place(pile, pile_at, Vector2(PILE_HALF_WIDTH * 2.0, 300))
	campaigns.place(self)
	debuff_beats.place(self, hand_view)
	wild.place(self)
	# The need panel, sheets and banner all lie over the pile.
	move_child(pile, need_panel.get_index())


func open(app: App) -> void:
	_app = app
	_controller = app.controller
	_hand = app.hand
	_wire_play(app)
	_wire_moments(app)
	_wire_menus(app)
	_replay_set()


## The event queue, the motion, the seats, the hand and the commands, wired to the run.
func _wire_play(app: App) -> void:
	pool.fill(_pool_parent)
	add_child(player)
	add_child(motion)
	player.motion = motion
	motion.setup(self, UiMotion.reduced())
	Settings.changed.connect(_on_setting)
	pile.setup(pool, _pool_parent, motion)
	hand_view.motion = motion
	_build_seats()
	_cards = TableCards.new(_controller, _hand, hand_view, seats)
	add_child(turn)
	turn.setup(seats, player, _controller)
	# The moments layer lies over everything, seats included, so a takeover dims it all.
	move_child(moments, -1)
	speech.setup(seats, app)
	board.setup(_controller.figures.cadre_slots(), board.size)
	# Wang's slip stands where the board is through the arrival, which holds no Cadre.
	board.visible = not app.arrival.is_running()
	need_panel.setup(
		_controller.figures.base_need(), app.need_cap(), _controller.figures.lie_cost()
	)
	hand_view.setup(_hand, pool)
	var prompts: Array[String] = PromptLines.every(_controller, false)
	prompts.append_array(PromptLines.every(_controller, true))
	actions.size_prompt(prompts)
	_commands.setup(_controller, _hand, hand_view, actions, need_panel, player)
	_commands.open_rules = cheat_sheet.toggle.bind(_controller)
	_commands.gate = app.arrival.attempt
	tutorial.setup(app, actions, hand_view, need_panel, cheat_sheet, pause, dressing)
	tutorial.watch(pile, player)
	player.played.connect(_on_event)
	player.winding.connect(_on_winding)
	player.drained.connect(_on_drained)
	_controller.event_emitted.connect(player.push)


## The ledger, the moments and the pieces that act the run's events out.
func _wire_moments(app: App) -> void:
	var names: Dictionary[int, String] = {
		Seats.PLAYER: tr("ledger.you"),
		Seats.RIGHT: app.seat_name(Seats.RIGHT),
		Seats.LEFT: app.seat_name(Seats.LEFT),
	}
	ledger.setup(names)
	_commands.set_names(names)
	var faces: Dictionary[int, Texture2D] = {}
	for seat: int in seats:
		faces[seat] = app.seat_portrait(seat, Vector2.ONE)
	moments.setup(ledger, pile, motion, player, seats, names, faces)
	moments.tally.visibility_changed.connect(_step_aside)
	_kept.setup(player, moments.callout, names, faces)
	swap_sheet.setup(app, pool)
	moments.hud = hud
	moments.controller = _controller
	moments.sequence.attach(board, debuffs, _controller)
	add_child(_close)
	_close.setup(player, pile, moments, hand_view, _cards)
	campaigns.setup(_controller, _hand, hand_view, actions, _commands, player, moments)
	campaigns.attach(pool, debuffs, _cards)
	columns.setup(seats, campaigns.tray, dressing, debuffs, actions)
	sit_out.setup(_controller, actions, _commands, player, app.arrival.is_running)
	sit_out.pace_changed.connect(_set_pace)
	debuff_beats.setup(_controller, _cards, hand_view, pool, player, moments, board)
	deal_beats.place(self, moments)
	deal_beats.setup(_controller, pile, hand_view, player)


## The pace, the menu, the deck sheet, the keys and the dread.
func _wire_menus(app: App) -> void:
	_set_pace()
	hud.menu.pressed.connect(_open_pause)
	deck = TableDeck.attach(self, pause, _controller, player)
	pause.resumed.connect(func() -> void: player.set_process(true))
	# The events wait behind the books' notice until it is acknowledged (ADR 0022).
	app.notice.hold(player)
	pause.wire(app)
	_resize.setup(self, app, pause)
	_input.setup(pause, cheat_sheet, actions, hand_view, _controller, _open_pause, _open_deck)
	_input.tray = campaigns.tray
	wild.setup(hand_view, pile, debuffs, moments, player, _commands, _input)
	_setup_dread(app)


## Joining mid-Set replays what already happened silently, without banners.
func _replay_set() -> void:
	_replaying = true
	_still(true)
	for event: RunEvent in _controller.set_events():
		player.push(event)
	player.flush()
	_still(false)
	_replaying = false
	_kept.after_replay(_controller.awaiting() == RunController.AWAIT_SWAP)
	hud.sync(_controller.run, _controller.figures.target())


## Plays every queued event at once, skipping the pacing.
func skip_events() -> void:
	speech.hurrying = true
	_still(true)
	player.flush()
	_still(false)
	speech.skip_all()


## While the queue is played at once, nothing moves: cards land where they lie and a
## won trick is cleared, not swept, so no tween outlives the catch-up and clears a
## later play.
func _still(on: bool) -> void:
	motion.set_still(on or UiMotion.reduced())


func keep_sort(mode: HandView.Sort) -> void:
	_commands.set_sort(mode)


func _open_pause() -> void:
	player.set_process(false)
	pause.open()


## The deck sheet over the table, its events held until it is closed, as from the menu.
func _open_deck() -> void:
	player.set_process(false)
	deck.open_deck()


## Keyboard and gamepad go through TableInput.
func _unhandled_input(event: InputEvent) -> void:
	if _input.handle(event):
		get_viewport().set_input_as_handled()


## Dread reads the run at round boundaries, and starts settled when the table opens.
func _setup_dread(app: App) -> void:
	var materials: Dictionary[String, ShaderMaterial] = DreadLayers.table_materials(
		app.post.material(), _atmosphere, dressing
	)
	var panels: Array[SeatPanel] = []
	panels.assign(seats.values())
	var slots: Dictionary[String, TextureRect] = {"table_surface": surface}
	dread.setup(materials, dressing, panels, slots, hand_view)
	speech.dread = dread
	dread.refresh(_controller.run, true)


func _exit_tree() -> void:
	dread.clear()
	if _controller != null and _controller.event_emitted.is_connected(player.push):
		_controller.event_emitted.disconnect(player.push)


## Seat 1 acts after you, so it sits on your right; seat 2 on your left. Both sit
## along the top edge of the play area, the same distance from its middle.
func _build_seats() -> void:
	for seat: int in [Seats.RIGHT, Seats.LEFT]:
		var panel: SeatPanel = SeatPanel.new()
		panel.setup(seat, _app.seat_name(seat), _app.seat_portrait(seat, SeatPanel.PICTURE_BOX))
		var x: float = (
			PLAY_CENTER + SEAT_OFFSET
			if seat == Seats.RIGHT
			else PLAY_CENTER - SEAT_OFFSET - SEAT_WIDTH
		)
		_place(panel, Vector2(x, 112), Vector2(SEAT_WIDTH, 0))
		seats[seat] = panel


func _on_event(event: RunEvent) -> void:
	# Rejoining replays the Set silently: nothing is said or played twice.
	if not _replaying:
		TableSounds.play(event, _landlord, _controller)
		speech.on_event(event)
	# Campaigns first, so a forced pass is tagged as one when its pass arrives.
	campaigns.on_event(event, _replaying or player.flushing)
	moments.on_event(event, _replaying or player.flushing)
	wild.on_event(event, _replaying or player.flushing)
	_resize.on_event(event)
	match event.type:
		RunEvent.Type.ROUND:
			_on_round_event(event.round_event)
		RunEvent.Type.ROUND_SCORED:
			ledger.set_final(event.seat, event.amount)
			dread.refresh(_controller.run)
		RunEvent.Type.SET_STARTED, RunEvent.Type.DEALT:
			_new_deal()
			dread.refresh(_controller.run)
		RunEvent.Type.SET_ENDED, RunEvent.Type.METER_CHANGED:
			dread.refresh(_controller.run)
		RunEvent.Type.LANDLORD_CHOSEN:
			_landlord = event.seat
			dread.refresh(_controller.run, false, event.seat)
		RunEvent.Type.CADRE_FIRED:
			if not (_replaying or player.flushing):
				board.fired(_controller, event.text, event.value)
	_refresh_status()


func _on_round_event(event: RoundEvent) -> void:
	match event.type:
		RoundEvent.Type.ROUND_STARTED:
			# A kept seat is never bid for again, so the round itself names the landlord.
			_landlord = event.seat
			ledger.start_round(event.seat)
			_show_roles(event.seat)
		RoundEvent.Type.KITTY_TAKEN:
			_count_cards(event.seat, event.card_ids.size())
		RoundEvent.Type.PLAYED:
			_show_play(event)
			_count_cards(event.seat, -event.cards.size())
			if event.seat == Seats.PLAYER:
				_close.own_play(event)
			if event.pattern.type == Pattern.Type.BOMB or event.pattern.type == Pattern.Type.ROCKET:
				motion.impact()
			ledger.set_pending(DirectiveSheet.type_name(event.pattern.type))
		RoundEvent.Type.TRICK_WON:
			# A replayed or skipped trick is cleared at once: a sweep still running would
			# clear the plays that come after it.
			if _replaying or player.flushing:
				pile.clear()
			else:
				pile.sweep(_cards.point(event.seat))


## A fresh deal wipes the last round off the table: lanes, ledger, speech, the
## round's banner and the landlord tag, and every villager back to a full hand. Your
## new hand rises in now, not after the bots' first plays.
func _new_deal() -> void:
	pile.clear()
	ledger.clear_rows()
	_landlord = Seats.NONE
	speech.skip_all()
	for seat: int in seats:
		_counts[seat] = Dealer.HAND_SIZE
	for panel: SeatPanel in seats.values():
		panel.set_count(Dealer.HAND_SIZE)
		panel.set_role(false, false)
		panel.say("")
	_hand.refresh()
	hand_view.show_cards()
	hand_view.deal_in()


func _on_drained() -> void:
	_refresh_seats()
	_refresh_status()
	var state: RunView = _controller.run
	hud.sync(state, _controller.figures.target())
	dressing.post_notice(
		DreadDressing.notice_key(state.year(), state.set_index() + state.round_index())
	)
	board.show_cadres(_controller)
	# A row of empty slots says nothing: the board stands once a Cadre is held.
	board.visible = not (_app.arrival.is_running() or state.held_cadres().is_empty())
	debuffs.show_debuffs(_controller)
	var awaiting: int = _controller.awaiting()
	actions.show_bidding(awaiting == RunController.AWAIT_BID)
	need_panel.visible = awaiting == RunController.AWAIT_NEED
	_clear_for_sheet()
	if awaiting == RunController.AWAIT_NEED:
		need_panel.ask(
			state.commons_pool(),
			_app.seat_name(Seats.teammate(Seats.PLAYER, _landlord)),
			_controller.figures.audit_chance()
		)
	_hand.refresh()
	hand_view.show_cards()
	campaigns.refresh()
	_commands.refresh()
	columns.fit()
	tutorial.settled(awaiting)
	_resize.drained(awaiting)
	if awaiting == RunController.AWAIT_SET_OVER or awaiting == RunController.AWAIT_RUN_OVER:
		_app.show_screen("set_summary", true)
	elif awaiting == RunController.AWAIT_SWAP:
		# The plot swap is a sheet over the table, opened once the queue is empty (ADR 0038).
		swap_sheet.open()


## A play flies to the pile from the seat that made it; yours leaves from your hand. Only
## your cards of a wild rank land wild: the ranks are yours alone (ADR 0039).
func _show_play(event: RoundEvent) -> void:
	var origins: Array[Vector2] = []
	if event.seat == Seats.PLAYER:
		for card: CardInstance in event.cards:
			origins.append(hand_view.card_center(card.id()))
	pile.show_play(
		event.cards, _cards.point(event.seat), origins, event.pattern, event.seat == Seats.PLAYER
	)


func _on_setting(key: String) -> void:
	if key == UiMotion.SETTING:
		motion.set_still(UiMotion.reduced())
	if key == UiMotion.SETTING or key == SettingsPanel.PACE_SETTING:
		_set_pace()


## The step between events, and every wait measured in it, at the pace chosen in
## settings: it takes hold at once, mid-round.
func _set_pace() -> void:
	player.step = _app.motion_step() * sit_out.pace()
	moments.sequence.hurrying_villagers = sit_out.is_active()
	player.play_wait = UiMotion.PRESETS.fly_time * player.step / UiMotion.PRESETS.event_step
	player.wind = _wind()
	player.holds = {
		RunEvent.Type.NEED_DECLARED: player.step, RunEvent.Type.SHARE_PAID: player.step * 1.6
	}


## The beat a villager's seat is marked for before its cards leave, at the table's pace;
## none under reduced motion.
func _wind() -> float:
	if motion.still:
		return 0.0
	return UiMotion.PRESETS.wind_up * player.step / UiMotion.PRESETS.event_step


func _on_winding(event: RunEvent) -> void:
	var seat: int = event.round_event.seat
	if not _replaying and seats.has(seat):
		motion.wind_up(seats[seat], player.wind)


## The seats take their roles as the round starts, and their card counts tick as cards
## are taken and played, without waiting for the queue to drain.
func _show_roles(landlord: int) -> void:
	for seat: int in seats:
		seats[seat].set_role(landlord == seat, Seats.teammate(Seats.PLAYER, landlord) == seat)
	_show_you(landlord)


## The line over your hand says your role, from the moment the round starts.
func _show_you(landlord: int) -> void:
	var role: String = "landlord" if landlord == Seats.PLAYER else "peasant"
	you.text = tr("table.you." + ("bidding" if landlord == Seats.NONE else role))
	_clear_for_sheet()


## The tally's band is the line's too: the line over the hand steps aside while a play's
## score is shown, its role told by then, and is back when the tally is put away.
func _step_aside() -> void:
	you.modulate.a = 0.0 if moments.tally.visible else 1.0


## The claim sheet lies over the line above the hand, and half a line showing under a
## sheet reads as a fault: the line is put away while the sheet is up, and the Glass
## Walls slip keeps clear of both.
func _clear_for_sheet() -> void:
	you.visible = not need_panel.visible
	debuff_beats.clear_slip(you, need_panel.visible)


func _count_cards(seat: int, change: int) -> void:
	if seats.has(seat):
		_counts[seat] = maxi(int(_counts.get(seat, Dealer.HAND_SIZE)) + change, 0)
		seats[seat].set_count(_counts[seat])


func _refresh_seats() -> void:
	var view: SeatView = _controller.table.seat_view()
	var landlord: int = _controller.run.landlord_seat()
	for seat: int in seats:
		var panel: SeatPanel = seats[seat]
		if view != null:
			panel.set_count(view.public.remaining[seat])
			_counts[seat] = view.public.remaining[seat]
			landlord = view.public.landlord
		var teammate: bool = Seats.teammate(Seats.PLAYER, landlord) == seat
		panel.set_role(landlord == seat, teammate)
		panel.set_intel(IntelText.for_seat(view.info if view != null else null, seat))
		var bid: String = moments.bid_key(seat)
		if landlord == Seats.NONE and not bid.is_empty():
			panel.set_bid(tr(bid))
	_show_you(landlord)


func _refresh_status() -> void:
	var state: RunView = _controller.run
	hud.show_state(state, _app.max_rounds())
	ledger.show_books(state, _controller.figures.target())


func _place(node: Control, at: Vector2, extent: Vector2) -> void:
	add_child(node)
	node.position = at
	node.size = extent
