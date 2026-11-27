extends GdUnitTestSuite
## Every slip and tooltip stands right beside what it explains : the Mutual Aid
## slip on the counter at the foot of the store stands beside it, not at the top of the
## screen; a slip slides along its side to keep off a button
## when it can, and covers one rather than leave its thing; an engine tooltip is moved
## beside the control it explains and off its button; and at the table, at both window
## sizes and every text size, a keyword's slip and a Cadre's tooltip on the notice board
## stand within SlipPlacer.REACH of their thing.

const SCREEN: Rect2 = Rect2(0, 0, 1920, 1080)
const FAR: Vector2 = Vector2(-500, -500)

var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size


func after_test() -> void:
	var tips: KeywordTips = KeywordTips.of(self)
	tips.tick(10.0, FAR)
	tips.tick(10.0, FAR)
	tips.process_mode = Node.PROCESS_MODE_INHERIT
	Settings.set_value(TextSize.SETTING, 0)
	Settings.set_value("reduced_motion", false)
	get_tree().root.size = _was_size
	Saves.run_service().delete()


## A piece at the foot of the screen, papers with Buy buttons over it: the slip stands
## at the piece's edge, not at the top of the screen.
func test_a_slip_over_papers_stays_on_its_piece() -> void:
	var host: Control = auto_free(Control.new())
	add_child(host)
	var piece: Rect2 = Rect2(40, 860, 190, 120)
	for y: float in [280.0, 470.0, 640.0]:
		_button(host, Rect2(380, y, 200, 56))
	var size: Vector2 = Vector2(430, 230)
	var at: Vector2 = SlipPlacer.place(size, piece, 10.0, SCREEN, host, null)
	var slip: Rect2 = Rect2(at, size)
	assert_float(SlipPlacer.distance(slip, piece)).is_less_equal(SlipPlacer.REACH)
	assert_bool(slip.intersects(piece)).is_false()
	assert_float(slip.position.y).is_greater(
		piece.position.y - size.y - SlipPlacer.REACH - ClipCheck.SLACK
	)


## A button where the slip would first stand: it slides along the same side to miss it.
func test_a_slip_slides_along_its_side_to_miss_a_button() -> void:
	var host: Control = auto_free(Control.new())
	add_child(host)
	var piece: Rect2 = Rect2(800, 600, 300, 100)
	var size: Vector2 = Vector2(300, 150)
	var bare: Vector2 = SlipPlacer.place(size, piece, 10.0, SCREEN, host, null)
	_button(host, Rect2(bare.x, bare.y + 60, 120, 40))
	var at: Vector2 = SlipPlacer.place(size, piece, 10.0, SCREEN, host, null)
	var slip: Rect2 = Rect2(at, size)
	assert_float(SlipPlacer.distance(slip, piece)).is_less_equal(SlipPlacer.REACH)
	assert_bool(slip.intersects(Rect2(bare.x, bare.y + 60, 120, 40))).is_false()


## Buttons all round: the slip covers one rather than leave its thing.
func test_a_slip_hemmed_in_by_buttons_still_touches_its_thing() -> void:
	var host: Control = auto_free(Control.new())
	add_child(host)
	var piece: Rect2 = Rect2(800, 500, 200, 80)
	_button(host, Rect2(0, 0, 1920, 495))
	_button(host, Rect2(0, 585, 1920, 495))
	_button(host, Rect2(0, 495, 795, 90))
	_button(host, Rect2(1005, 495, 915, 90))
	var size: Vector2 = Vector2(300, 150)
	var slip: Rect2 = Rect2(SlipPlacer.place(size, piece, 10.0, SCREEN, host, null), size)
	assert_float(SlipPlacer.distance(slip, piece)).is_less_equal(SlipPlacer.REACH)
	assert_bool(slip.intersects(piece)).is_false()


## Near the top edge, above has no room: the slip goes below, still beside its thing.
func test_a_slip_with_no_room_above_goes_below() -> void:
	var piece: Rect2 = Rect2(600, 30, 200, 80)
	var size: Vector2 = Vector2(300, 150)
	var slip: Rect2 = Rect2(SlipPlacer.place(size, piece, 10.0, SCREEN, null, null), size)
	assert_float(slip.position.y).is_greater_equal(piece.end.y)
	assert_float(SlipPlacer.distance(slip, piece)).is_less_equal(SlipPlacer.REACH)


## The engine's tooltip, which it lays at the pointer, is moved beside the card it was
## shown for and off the card's own button.
func test_an_engine_tooltip_moves_beside_its_card() -> void:
	var host: Control = auto_free(Control.new())
	host.size = SCREEN.size
	add_child(host)
	var card: PanelContainer = PanelContainer.new()
	card.position = Vector2(700, 400)
	card.size = Vector2(300, 400)
	host.add_child(card)
	var buy: Button = Button.new()
	buy.position = Vector2(20, 340)
	buy.size = Vector2(260, 50)
	card.add_child(buy)
	var placer: TipPlacer = auto_free(TipPlacer.new())
	add_child(placer)
	var panel: PopupPanel = PopupPanel.new()
	panel.theme_type_variation = TipPlacer.VARIATION
	panel.size = Vector2i(280, 120)
	# Where the engine puts it: at the pointer on the card's button, over the card.
	panel.position = Vector2i(760, 760)
	card.add_child(panel)
	placer.settle(panel)
	var tip: Rect2 = Rect2(Vector2(panel.position), Vector2(panel.size))
	var thing: Rect2 = Rect2(Vector2(700, 400), Vector2(300, 400))
	assert_bool(tip.grow(-ClipCheck.SLACK).intersects(thing)).is_false()
	assert_float(SlipPlacer.distance(tip, thing)).is_less_equal(SlipPlacer.REACH)
	assert_bool(SCREEN.encloses(tip)).is_true()
	panel.queue_free()


## At the table: the slip for a keyword in the debuff strip, and the tooltip for a held
## Cadre on the notice board, at both window sizes and every text size.
func test_slips_at_the_table_stand_beside_their_thing() -> void:
	AppKit.fresh_saves(self)
	var app: App = AppKit.make(self)
	app.new_run(4242)
	var loop: RunLoop = app.controller.run_loop()
	if loop.state.inventory.cadres.is_empty():
		loop.state.inventory.cadres.append("canteen")
	Settings.set_value("reduced_motion", true)
	var placer: TipPlacer = auto_free(TipPlacer.new())
	add_child(placer)
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		for screen_size: Vector2i in ClipCheck.SIZES:
			get_tree().root.size = screen_size
			var table: TableScreen = app.show_screen(ScreenId.TABLE, true)
			await await_idle_frame()
			await await_idle_frame()
			var where: String = "table %s text %d" % [screen_size, level]
			await _check_keyword(table, where)
			_check_board_tip(table, placer, where)


func _check_keyword(table: Control, where: String) -> void:
	var found: RegExMatch = null
	var text: KeywordText = null
	for node: Node in table.find_children("*", "KeywordText", true, false):
		var candidate: KeywordText = node as KeywordText
		found = RegEx.create_from_string("\\[url=([a-z_]+)\\]").search(candidate.text)
		if found != null and candidate.is_visible_in_tree():
			text = candidate
			break
	if text == null:
		return
	var tips: KeywordTips = KeywordTips.of(self)
	tips.process_mode = Node.PROCESS_MODE_DISABLED
	var at: Vector2 = text.get_global_rect().position + Vector2(20, 10)
	text.meta_hover_started.emit(found.get_string(1))
	tips.tick(KeywordTips.DELAY + 0.01, at)
	await await_idle_frame()
	await await_idle_frame()
	tips.tick(0.01, at)
	var shown: KeywordSlip = tips.slips()[-1]
	var slip: Rect2 = shown.get_global_rect()
	var word: Rect2 = Rect2(at, Vector2.ZERO).grow(KeywordTips.POINTER)
	_check(slip, word, where + " keyword")
	text.meta_hover_ended.emit(found.get_string(1))
	tips.tick(10.0, FAR)
	tips.tick(10.0, FAR)


func _check_board_tip(table: TableScreen, placer: TipPlacer, where: String) -> void:
	var board: NoticeBoard = table.board
	var card: Control = null
	for node: Node in board.get_children():
		if node is TipHost and not (node as TipHost).tip_rule().is_empty():
			card = node as Control
			break
	assert_object(card).override_failure_message(where + ": no held Cadre").is_not_null()
	var panel: PopupPanel = PopupPanel.new()
	panel.theme_type_variation = TipPlacer.VARIATION
	panel.size = Vector2i(420, 200)
	card.add_child(panel)
	placer.settle(panel)
	var tip: Rect2 = Rect2(Vector2(panel.position), Vector2(panel.size))
	_check(tip, card.get_global_rect(), where + " board")
	panel.queue_free()


func _check(slip: Rect2, thing: Rect2, where: String) -> void:
	var screen: Rect2 = get_tree().root.get_visible_rect().grow(ClipCheck.SLACK)
	(
		assert_bool(screen.encloses(slip))
		. override_failure_message("%s: %s off" % [where, slip])
		. is_true()
	)
	(
		assert_bool(slip.grow(-ClipCheck.SLACK).intersects(thing))
		. override_failure_message("%s: %s over %s" % [where, slip, thing])
		. is_false()
	)
	(
		assert_float(SlipPlacer.distance(slip, thing))
		. override_failure_message("%s: %s far from %s" % [where, slip, thing])
		. is_less_equal(SlipPlacer.REACH + ClipCheck.SLACK)
	)


func _button(host: Control, rect: Rect2) -> void:
	var button: Button = Button.new()
	button.position = rect.position
	button.size = rect.size
	host.add_child(button)
