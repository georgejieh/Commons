extends GdUnitTestSuite
## Campaigns at the table and in the shops (ADR 0021): the tray shows the held leaflets
## clear of the hand, the buttons, the notice and the prompt line; arming and cancelling
## leave nothing behind; a leaflet that cannot be used says so at full strength; a use
## plays out and leaves no node behind; a quiet replay shows only the end state; the
## keyboard reaches the tray; every Campaign paper is aged at stage 0 and more at the
## last stage; and the shops offer a Campaign and its tray without passing 1080.

const SEED: int = 4242
const SAVE_PATH: String = "user://test_campaign_ui/run.json"
const WAIT_SECONDS: float = 6.0
const SCREEN: Vector2i = Vector2i(1920, 1080)

var _app: DemoApp
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	get_tree().root.size = SCREEN
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)
	_app.new_run(SEED)


func after_test() -> void:
	get_tree().root.size = _was_size
	ArtStages.stage_override = -1
	Settings.set_value("reduced_motion", false)
	Saves.run_service().delete()


## Tests hand the player Campaigns directly; a run only gets them from a shop.
func _hold(held: Array[String]) -> void:
	var loop: RunLoop = _app.controller.get("_loop")
	loop.state.inventory.consumables.assign(held)


func _record_size() -> int:
	var loop: RunLoop = _app.controller.get("_loop")
	return loop.record.commands.size()


## Plays the player's seat until the run waits on moment.
func _drive_to(moment: int) -> bool:
	var driver: ControllerScript = ControllerScript.new()
	for _step: int in 900:
		var awaiting: int = _app.controller.awaiting()
		if awaiting == moment:
			return true
		if awaiting == RunController.AWAIT_SET_OVER:
			_app.controller.finish_set()
		elif awaiting == RunController.AWAIT_STORE:
			_app.controller.leave_store()
		elif not driver.act(_app.controller):
			return false
	return false


func _open_table() -> TableScreen:
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	await await_idle_frame()
	return table


func _campaigns(table: TableScreen) -> TableCampaigns:
	return table.get("_campaigns")


func _wait_idle(table: TableScreen) -> void:
	var player: EventPlayer = table.get("_player")
	var waited: float = 0.0
	while (
		(not player.is_idle() or _campaigns(table).moments.is_playing()) and waited < WAIT_SECONDS
	):
		await get_tree().process_frame
		waited += get_process_delta_time()


func _press(table: TableScreen, action: String) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	table.call("_unhandled_input", event)


func test_the_tray_shows_held_leaflets_clear_of_the_table() -> void:
	_hold(["model_harvest", "anonymous_letter"])
	assert_bool(_drive_to(RunController.AWAIT_PLAY)).is_true()
	var table: TableScreen = await _open_table()
	var tray: CampaignTray = _campaigns(table).tray
	assert_bool(tray.leaflet(0).visible).is_true()
	assert_str(tray.leaflet(0).shown_name()).is_equal(tr("campaign.model_harvest.name"))
	assert_bool(tray.leaflet(1).is_private()).is_true()
	assert_str(tray.leaflet(0).tip_rule()).is_equal(_app.controller.campaign_text("model_harvest"))
	CampaignTrayLayout.check_clear(self, table, Vector2(SCREEN))


func test_arming_then_cancelling_leaves_no_state_behind() -> void:
	_hold(["model_harvest"])
	assert_bool(_drive_to(RunController.AWAIT_PLAY)).is_true()
	var table: TableScreen = await _open_table()
	var tray: CampaignTray = _campaigns(table).tray
	var hand: HandModel = _app.hand
	var reading: String = table.actions().reading.text
	var before: Dictionary = _app.controller.state_copy().to_dict()
	var commands: int = _record_size()
	hand.toggle(hand.cards()[0].id())
	tray.leaflet(0).chosen.emit(0)
	assert_int(tray.armed_slot()).is_equal(0)
	assert_bool(tray.use.visible).is_true()
	assert_array(hand.selected_ids()).is_empty()
	# Armed, the Use and Cancel buttons stay clear of the trick and the hand too.
	var pile: Control = table.get("_pile")
	var hand_view: Control = table.get("_hand_view")
	for button: Button in [tray.use, tray.cancel]:
		assert_bool(button.get_global_rect().intersects(pile.get_global_rect())).is_false()
		assert_bool(button.get_global_rect().intersects(hand_view.get_global_rect())).is_false()
	assert_str(table.actions().reading.text).is_equal(
		_app.controller.campaign_prompt("model_harvest")
	)
	assert_bool(table.actions().play.disabled).is_true()
	hand.toggle(hand.cards()[1].id())
	tray.cancel.pressed.emit()
	assert_int(tray.armed_slot()).is_equal(-1)
	assert_bool(tray.use.visible).is_false()
	assert_array(hand.selected_ids()).is_empty()
	assert_str(table.actions().reading.text).is_equal(reading)
	assert_dict(_app.controller.state_copy().to_dict()).is_equal(before)
	assert_int(_record_size()).is_equal(commands)


## A leaflet that cannot be used now stays at full strength, so it never reads as gone,
## and says so in its own red line, with the reason in its slip.
func test_a_leaflet_that_cannot_be_used_says_so_at_full_strength() -> void:
	_hold(["mutual_aid", "grain_loan"])
	assert_bool(_drive_to(RunController.AWAIT_BID)).is_true()
	var table: TableScreen = await _open_table()
	var tray: CampaignTray = _campaigns(table).tray
	for slot: int in 2:
		var leaflet: CampaignLeaflet = tray.leaflet(slot)
		assert_float(leaflet.modulate.a).is_equal(1.0)
		assert_bool(leaflet.says_not_now()).is_true()
		assert_str(leaflet.tip_rule()).contains(tr("campaign.reason.not_now"))
		leaflet.chosen.emit(slot)
		assert_int(tray.armed_slot()).is_equal(-1)
	# Every refusal has its words, and a lit leaflet keeps its rule alone.
	var sample: CampaignLeaflet = auto_free(CampaignLeaflet.new())
	add_child(sample)
	sample.show_campaign(0, "appeal", "Appeal", "rule", false)
	for reason: int in CampaignEffect.Reason.values():
		if reason == CampaignEffect.Reason.OK:
			continue
		var why: String = tr(RunController.campaign_reason_key(reason))
		sample.set_reason(reason, why)
		assert_float(sample.modulate.a).is_equal(1.0)
		assert_bool(sample.says_not_now()).is_true()
		assert_str(sample.tip_rule()).contains(why)
		sample.set_reason(0, "")
		assert_bool(sample.says_not_now()).is_false()
		assert_str(sample.tip_rule()).is_equal("rule")


func test_a_use_plays_out_marks_the_hand_and_leaves_no_node_behind() -> void:
	_hold(["model_harvest"])
	assert_bool(_drive_to(RunController.AWAIT_PLAY)).is_true()
	var table: TableScreen = await _open_table()
	var campaigns: TableCampaigns = _campaigns(table)
	var pool: CardPool = table.get("_pool")
	var free: int = pool.free_count()
	var parts: int = campaigns.moments.get_child_count()
	var hand: HandModel = _app.hand
	var chosen: Array[int] = [hand.cards()[0].id(), hand.cards()[1].id()]
	campaigns.tray.arm(0)
	for card_id: int in chosen:
		hand.toggle(card_id)
	campaigns.tray.use_armed()
	var played: bool = false
	for _frame: int in 60:
		await get_tree().process_frame
		played = played or campaigns.moments.is_playing()
	assert_bool(played).is_true()
	await _wait_idle(table)
	assert_bool(campaigns.moments.is_playing()).is_false()
	assert_int(campaigns.moments.get_child_count()).is_equal(parts)
	assert_int(pool.free_count()).is_equal(free)
	var hand_view: HandView = table.get("_hand_view")
	var marked: int = 0
	for child: Node in hand_view.get_children():
		var view: CardView = child as CardView
		if view != null and view.visible and chosen.has(view.card_id):
			assert_bool(view.shows_model()).is_true()
			marked += 1
	assert_int(marked).is_equal(2)
	assert_bool(campaigns.tray.leaflet(0).visible).is_false()


func test_a_seizure_flies_real_cards_and_gives_the_pool_back() -> void:
	_hold(["seizure_notice"])
	assert_bool(_drive_to(RunController.AWAIT_PLAY)).is_true()
	var table: TableScreen = await _open_table()
	var campaigns: TableCampaigns = _campaigns(table)
	var pool: CardPool = table.get("_pool")
	var free: int = pool.free_count()
	campaigns.tray.arm(0)
	campaigns.tray.use_armed()
	await _wait_idle(table)
	assert_int(pool.free_count()).is_equal(free)
	assert_bool(campaigns.moments.is_playing()).is_false()


func test_a_quiet_replay_shows_the_letter_at_its_seat_and_nothing_moving() -> void:
	_hold(["anonymous_letter"])
	assert_bool(_drive_to(RunController.AWAIT_PLAY)).is_true()
	assert_int(_app.controller.campaign(0)).is_equal(RunController.OK)
	var table: TableScreen = await _open_table()
	var moments: CampaignMoments = _campaigns(table).moments
	assert_bool(moments.letter_out()).is_true()
	assert_bool(moments.is_playing()).is_false()
	var note: Control = moments.get("_note")
	assert_bool(note.visible).is_true()


func test_the_keyboard_reaches_the_tray_and_backs_out() -> void:
	_hold(["grain_loan", "model_harvest"])
	assert_bool(_drive_to(RunController.AWAIT_PLAY)).is_true()
	var table: TableScreen = await _open_table()
	var tray: CampaignTray = _campaigns(table).tray
	_press(table, "commons_campaign")
	assert_int(tray.cursor_slot()).is_equal(0)
	assert_bool(tray.leaflet(0).cursor).is_true()
	_press(table, "commons_play")
	assert_int(tray.armed_slot()).is_equal(0)
	_press(table, "ui_cancel")
	assert_int(tray.armed_slot()).is_equal(-1)
	var pause: PauseMenu = table.get("_pause")
	assert_bool(pause.visible).is_false()
	_press(table, "commons_campaign")
	assert_int(tray.cursor_slot()).is_equal(1)
	_press(table, "commons_campaign")
	assert_int(tray.cursor_slot()).is_equal(-1)


## Nothing drawn is clean: the paper is aged at stage 0 and more so at the last stage,
## and every piece draws at both.
func test_campaign_paper_is_aged_and_wears_with_the_stage() -> void:
	ArtStages.stage_override = 0
	var fresh: float = BowlGrime.wear()
	var paper: Color = CampaignPaper.paper(fresh)
	assert_float(fresh).is_greater(0.0)
	assert_bool(paper.is_equal_approx(Color.WHITE)).is_false()
	assert_bool(paper.is_equal_approx(CampaignPaper.PAPER)).is_false()
	var leaflet: CampaignLeaflet = auto_free(CampaignLeaflet.new())
	add_child(leaflet)
	leaflet.show_campaign(0, "grain_loan", "Grain Loan", "rule", false)
	var mark: CardMark = auto_free(CardMark.new(CardMark.Kind.MODEL))
	add_child(mark)
	mark.visible = true
	await await_idle_frame()
	ArtStages.stage_override = BoardState.CORRUPTION_STAGES - 1
	var worn: float = BowlGrime.wear()
	assert_float(worn).is_greater(fresh)
	assert_float(CampaignPaper.paper(worn).get_luminance()).is_less(paper.get_luminance())
	leaflet.queue_redraw()
	mark.queue_redraw()
	await await_idle_frame()


func test_the_shops_offer_a_campaign_and_its_tray_within_1080() -> void:
	var driver: ControllerScript = ControllerScript.new()
	while _app.controller.awaiting() != RunController.AWAIT_SET_OVER:
		driver.act(_app.controller)
	_app.controller.finish_set()
	var loop: RunLoop = _app.controller.get("_loop")
	loop.state.coupons = 60
	for screen_id: String in ["store", "black_market"]:
		var store: StoreScreen = _app.show_screen(screen_id, true)
		await await_idle_frame()
		await await_idle_frame()
		var stall: CampaignStall = store.get("_campaign_stall")
		var buy: Button = null
		for node: Node in store.find_children("*", "Button", true, false):
			var button: Button = node as Button
			if (
				button.is_visible_in_tree()
				and button.text.begins_with(tr("store.buy").split("{")[0])
			):
				if _within(button, stall):
					buy = button
		assert_object(buy).is_not_null()
		_check_inside(store, screen_id)
		var held: int = _app.controller.held_campaigns().size()
		buy.pressed.emit()
		var waited: float = 0.0
		while stall.is_busy() and waited < WAIT_SECONDS:
			await get_tree().process_frame
			waited += get_process_delta_time()
		assert_int(_app.controller.held_campaigns().size()).is_equal(held + 1)
		assert_bool(stall.tray.leaflet(held).visible).is_true()


func _within(button: Button, stall: CampaignStall) -> bool:
	var offers: Control = stall.get("_offers")
	return offers.is_ancestor_of(button)


func _check_inside(root: Node, where: String) -> void:
	var screen: Rect2 = Rect2(Vector2.ZERO, Vector2(SCREEN)).grow(1.5)
	for node: Node in root.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if not control.is_visible_in_tree() or control is TextureRect or control is ColorRect:
			continue
		# The page's margin box may run past the bottom by its own margin, as every page
		# does; it must still fit the width, and what it holds must fit.
		if control is MarginContainer and control.get_parent() == root:
			assert_float(control.size.x).is_less_equal(float(SCREEN.x))
			continue
		var rect: Rect2 = control.get_global_rect()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0 or rect.position.x < -1000.0:
			continue
		(
			assert_bool(screen.encloses(rect))
			. override_failure_message("%s: %s at %s" % [where, control.get_path(), rect])
			. is_true()
		)


func test_the_opening_offers_play_on_and_plays_on() -> void:
	_hold(["mutual_aid"])
	assert_bool(_drive_to(RunController.AWAIT_OPENING)).is_true()
	var table: TableScreen = await _open_table()
	var actions: ActionBar = table.actions()
	assert_bool(actions.play_on.is_visible_in_tree()).is_true()
	assert_str(actions.reading.text).is_equal(tr("campaign.opening"))
	assert_float(_campaigns(table).tray.leaflet(0).modulate.a).is_equal(1.0)
	actions.play_on.pressed.emit()
	assert_int(_app.controller.awaiting()).is_not_equal(RunController.AWAIT_OPENING)
	assert_bool(actions.play_on.visible).is_false()


func test_the_round_result_states_a_stake() -> void:
	var won: Dictionary = {"stake": true, "banked": 3000.0}
	assert_str(RoundSummaryScreen.stake_line(won)).is_equal(
		tr("round.stake.won").format({"amount": Strings.score(3000.0)})
	)
	assert_str(RoundSummaryScreen.stake_line({"stake": false, "banked": 0.0})).is_equal(
		tr("round.stake.lost")
	)
