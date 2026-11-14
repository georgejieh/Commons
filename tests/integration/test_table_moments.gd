extends GdUnitTestSuite
## The table acted out: a call takes the screen, a pass is tagged on its seat, a score
## is counted in chits, every claim on the Commons shows its audit, and the need panel
## states a claim as a share and stays on screen.


func test_the_need_panel_says_what_a_declaration_pays() -> void:
	var panel: NeedPanel = auto_free(NeedPanel.new())
	add_child(panel)
	panel.setup(10, 40, 5)
	panel.ask(1200, "Zhao", 0.15)
	assert_int(panel.percent()).is_equal(50)
	assert_int(panel.preview_share()).is_equal(600)
	var shown: Label = panel.get("_value")
	assert_str(shown.text).is_equal("50%")
	var more: Button = panel.get("_more")
	for _step: int in 10:
		more.pressed.emit()
	assert_int(panel.value()).is_equal(20)
	assert_int(panel.percent()).is_equal(67)
	assert_int(panel.preview_share()).is_equal(800)
	var note: Label = panel.get("_note")
	assert_str(note.text).is_equal(tr("need.lie").format({"rise": 5, "chance": 15}))


func test_the_need_panel_stays_on_screen_and_centered() -> void:
	var panel: NeedPanel = auto_free(NeedPanel.new())
	add_child(panel)
	panel.center = Vector2(790, 520)
	panel.setup(10, 40, 5)
	panel.ask(1900, "Zhao", 0.15)
	await await_millis(200)
	assert_float(panel.position.y + panel.size.y).is_less(760.0)
	assert_float(panel.position.x + panel.size.x / 2.0).is_equal_approx(790.0, 1.0)
	var declare: Button = panel.get("_declare")
	assert_float(declare.size.x).is_less(panel.size.x * 0.7)


func test_a_call_takes_the_screen_and_every_bid_stays_on_its_seat() -> void:
	var wang: SeatPanel = auto_free(SeatPanel.new())
	var zhao: SeatPanel = auto_free(SeatPanel.new())
	add_child(wang)
	add_child(zhao)
	var seats: Dictionary[int, SeatPanel] = {1: wang, 2: zhao}
	var moments: TableMoments = _moments(seats)
	moments.on_event(RunEvent.new(RunEvent.Type.BID, 1, 1))
	assert_str(moments.callout.shown_word()).is_equal(tr("callout.call").to_upper())
	assert_str(moments.callout.shown_sub()).is_equal(
		tr("callout.call.sub").format({"name": "Wang"})
	)
	moments.on_event(RunEvent.new(RunEvent.Type.BID, 2, 1))
	assert_str(moments.callout.shown_word()).is_equal(tr("callout.grab").to_upper())
	moments.on_event(RunEvent.new(RunEvent.Type.BID, 0, 0))
	moments.on_event(RunEvent.new(RunEvent.Type.BID, 1, 1))
	assert_str(moments.bid_key(1)).is_equal("bid.grab")
	assert_str(moments.bid_key(2)).is_equal("bid.grab")
	assert_str(moments.bid_key(0)).is_equal("bid.pass")
	var role: Label = wang.get("_role")
	assert_str(role.text).is_equal(tr("bid.grab").to_upper())
	moments.on_event(RunEvent.new(RunEvent.Type.LANDLORD_CHOSEN, 1, 0))
	assert_str(moments.bid_key(1)).is_empty()
	# A replayed bid is kept on the seat, but nothing is shouted.
	moments.callout.dismiss()
	moments.on_event(RunEvent.new(RunEvent.Type.BID, 2, 1), true)
	assert_bool(moments.callout.is_showing()).is_false()


func test_a_pass_is_tagged_on_its_seat_and_the_role_comes_back() -> void:
	var zhao: SeatPanel = auto_free(SeatPanel.new())
	add_child(zhao)
	zhao.set_role(false, true)
	var role: Label = zhao.get("_role")
	zhao.flash(tr("stamp.pass"))
	assert_str(role.text).is_equal(tr("stamp.pass").to_upper())
	await await_millis(int(SeatPanel.FLASH_HOLD * 1000.0) + 200)
	assert_str(role.text).is_equal(tr("table.role.teammate").to_upper())


func test_the_tally_counts_a_score_and_says_when_it_lands() -> void:
	var tally: ScoreTally = auto_free(ScoreTally.new())
	add_child(tally)
	var landed: Array[String] = []
	tally.landed.connect(func(total: String) -> void: landed.append(total))
	var seconds: float = tally.show_score(54.0, 7.0, 1.0, 378.0, 0.2)
	assert_float(seconds).is_greater(0.0)
	assert_array(landed).is_empty()
	await await_millis(int(seconds * 1000.0) + 250)
	assert_array(landed).is_equal(["378"])
	assert_str(tally.shown()).is_equal("54 × 7 × 1 = 378")
	# Reduced motion shows the sum at once.
	Settings.set_value("reduced_motion", true)
	assert_float(tally.show_score(16.0, 3.0, 0.75, 36.0)).is_equal(0.0)
	assert_str(tally.shown()).is_equal("16 × 3 × 0.75 = 36")
	Settings.set_value("reduced_motion", false)


func test_a_callout_comes_down_by_itself() -> void:
	var callout: Callout = auto_free(Callout.new())
	add_child(callout)
	callout.size = Vector2(1920, 1080)
	var seconds: float = callout.shout("Bomb!", Callout.Tier.TAKEOVER, ScreenKit.RED, "Zhao")
	assert_bool(callout.is_showing()).is_true()
	assert_str(callout.shown_word()).is_equal("BOMB!")
	await await_millis(int(seconds * 1000.0) + 300)
	assert_bool(callout.is_showing()).is_false()


func test_the_audit_slip_shows_each_claim_its_verdict_and_its_pay() -> void:
	var slip: AuditSlip = auto_free(AuditSlip.new())
	add_child(slip)
	var names: Dictionary[int, String] = {0: "You", 2: "Zhao"}
	slip.setup(names)
	slip.claim(0, 20)
	slip.claim(2, 10)
	assert_bool(slip.visible).is_true()
	assert_str(slip.row_text(0)).contains(tr("audit.claim").format({"name": "You", "percent": 67}))
	assert_str(slip.row_text(2)).contains(tr("audit.rolling"))
	slip.audited(0, true)
	slip.paid(0, 600)
	slip.paid(2, 600)
	assert_str(slip.row_text(0)).contains(tr("audit.caught"))
	assert_str(slip.row_text(0)).contains(tr("audit.paid").format({"amount": Strings.score(600)}))
	assert_str(slip.row_text(2)).contains(tr("audit.clear"))
	slip.clear()
	assert_bool(slip.visible).is_false()


## The table's moments layer with everything it drives, standing alone.
func _moments(seats: Dictionary[int, SeatPanel]) -> TableMoments:
	var moments: TableMoments = auto_free(TableMoments.new())
	var ledger: Ledger = auto_free(Ledger.new())
	var pile: TrickPile = auto_free(TrickPile.new())
	var motion: TableMotion = auto_free(TableMotion.new())
	var player: EventPlayer = auto_free(EventPlayer.new())
	for node: Node in [moments, ledger, pile, motion, player]:
		add_child(node)
	moments.size = Vector2(1920, 1080)
	var names: Dictionary[int, String] = {0: "You", 1: "Wang", 2: "Zhao"}
	var faces: Dictionary[int, Texture2D] = {}
	moments.setup(ledger, pile, motion, player, seats, names, faces)
	return moments


func test_the_quota_bar_fills_as_points_arrive_and_is_sealed_when_met() -> void:
	var hud: TableHud = auto_free(TableHud.new())
	add_child(hud)
	Settings.set_value("reduced_motion", true)
	hud.start_quota(1000.0)
	assert_bool(hud.is_met()).is_false()
	hud.add_progress(400.0)
	assert_float(hud.goal(TableHud.QUOTA)).is_equal(400.0)
	assert_float(hud.quota.value).is_equal(400.0)
	assert_bool(hud.is_met()).is_false()
	hud.add_progress(700.0)
	assert_float(hud.quota.value).is_equal(1000.0)
	assert_bool(hud.is_met()).is_true()
	hud.nudge_meter(TableHud.FAMINE, 10.0)
	assert_float(hud.famine.value).is_equal(10.0)
	# A new Quota empties the bar and lifts the seal.
	hud.start_quota(2000.0)
	assert_float(hud.quota.value).is_equal(0.0)
	assert_bool(hud.is_met()).is_false()
	Settings.set_value("reduced_motion", false)


func test_a_moment_that_holds_the_queue_finishes_before_the_table_moves_on() -> void:
	var player: EventPlayer = auto_free(EventPlayer.new())
	add_child(player)
	var drains: Array[int] = [0]
	player.drained.connect(func() -> void: drains[0] += 1)
	player.played.connect(func(_event: RunEvent) -> void: player.hold(0.4))
	player.push(RunEvent.new(RunEvent.Type.SET_ENDED, Seats.NONE, 1, 10.0))
	await await_millis(150)
	assert_int(drains[0]).is_equal(0)
	assert_bool(player.is_idle()).is_false()
	await await_millis(500)
	assert_int(drains[0]).is_equal(1)
	assert_bool(player.is_idle()).is_true()


func test_the_end_of_a_quota_takes_the_screen() -> void:
	var seats: Dictionary[int, SeatPanel] = {}
	var moments: TableMoments = _moments(seats)
	moments.on_event(RunEvent.new(RunEvent.Type.SET_STARTED, Seats.NONE, 0, 1500.0))
	moments.on_event(RunEvent.new(RunEvent.Type.SET_ENDED, Seats.NONE, 1, 1600.0))
	assert_str(moments.callout.shown_word()).is_equal(tr("callout.quota.met").to_upper())
	assert_str(moments.callout.shown_sub()).is_equal(
		tr("callout.quota.sub").format({"progress": "1.6K", "target": "1.5K"})
	)
	moments.on_event(RunEvent.new(RunEvent.Type.SET_ENDED, Seats.NONE, 0, 900.0))
	assert_str(moments.callout.shown_word()).is_equal(tr("callout.quota.missed").to_upper())


func test_information_cadres_show_what_they_reveal_on_the_seat() -> void:
	var info: InfoView = InfoView.new()
	var types: PackedInt32Array = PackedInt32Array()
	types.resize(Pattern.Type.size())
	types[Pattern.Type.PAIR] = 2
	types[Pattern.Type.BOMB] = 1
	info.opponent_types[1] = types
	info.closest_seat = 2
	var counts: PackedByteArray = PackedByteArray()
	counts.resize(Ranks.COUNT)
	counts[Ranks.THREE] = 2
	counts[Ranks.KING] = 1
	info.closest_counts = counts
	var bomb: String = tr("pattern.bomb")
	var pair: String = tr("pattern.pair")
	assert_str(IntelText.for_seat(info, 1)).is_equal(
		tr("intel.types").format({"list": "1 %s, 2 %s" % [bomb, pair]})
	)
	assert_str(IntelText.for_seat(info, 2)).is_equal(tr("intel.cards").format({"list": "3 3 K"}))
	assert_str(IntelText.for_seat(null, 1)).is_empty()
	var panel: SeatPanel = auto_free(SeatPanel.new())
	add_child(panel)
	panel.set_intel(IntelText.for_seat(info, 2))
	assert_str(panel.intel()).contains("3 3 K")
	panel.set_intel("")
	assert_str(panel.intel()).is_empty()


func test_a_cut_total_still_adds_up_on_the_tally() -> void:
	assert_int(ScoreTally.scale_percent(25.0, 7.0, 1.0, 175.0)).is_equal(100)
	assert_int(ScoreTally.scale_percent(25.0, 7.0, 1.0, 87.5)).is_equal(50)
	assert_int(ScoreTally.scale_percent(25.0, 7.0, 1.0, 0.0)).is_equal(0)
	assert_int(ScoreTally.scale_percent(0.0, 7.0, 1.0, 0.0)).is_equal(100)
	var tally: ScoreTally = auto_free(ScoreTally.new())
	add_child(tally)
	Settings.set_value("reduced_motion", true)
	tally.show_score(25.0, 7.0, 1.0, 87.5)
	assert_str(tally.shown()).contains(tr("tally.scaled").format({"percent": 50}))
	Settings.set_value("reduced_motion", false)
