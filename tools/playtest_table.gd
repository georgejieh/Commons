extends WalkBase
## The playtest's frames at the table (tools/playtest_demo.gd walks there): a tour that
## presses every control once and acts out the big moments by hand, the hint's ticks, the
## dice, the fan checked against the hand, leaving for the title and continuing, and a
## Campaign's turn with real clicks in a sandbox put back after.
## Development only; tools/ never ships.

## Corruption stages the dice bowl is photographed at, settled on a 1 and a 4.
const BOWL_STAGES: Array[int] = [0, 3, 6, 9]
## What awaiting() says while the bid is the player's.
const AWAIT_BID: int = 1

## True once the hint's tick has been photographed on a hand with a play to make.
var hint_shot: bool = false


## Presses every table control once and photographs the result.
func tour(table: Node) -> void:
	await _moment_frames(table)
	var actions: Object = table.call("actions")
	for mode: int in 3:
		await _press(actions.get("sort"))
		await _frames(30)
		await _shot("tour_sort%d" % mode)
	await _press(actions.get("hint"))
	await _frames(20)
	await _shot("tour_hint")
	var hand: Object = app.get("hand")
	hand.call("clear")
	await _refusal_frame()
	await _press(actions.get("rules"))
	await _frames(30)
	await _shot("tour_rules")
	await _mouse_click(Vector2(60, 1040))
	await _frames(10)
	var hud: Object = member(table, "_hud")
	await _press(hud.get("menu"))
	await _frames(30)
	await _shot("tour_menu")
	var pause: Node = member(table, "_pause")
	await _press_text_in(pause, tr("pause.settings"))
	await _frames(30)
	await _shot("tour_menu_settings")
	# The Controls page and back (ADR 0035): its Back is the only one showing.
	await _press_text_in(pause, tr("controls.open"))
	await _frames(30)
	await _shot("tour_menu_controls")
	await _press_text_in(pause, tr("settings.back"))
	await _frames(10)
	# The Window page and back, looked at and left as it is.
	await _press_text_in(pause, tr("settings.window"))
	await _frames(30)
	await _shot("tour_menu_window")
	await _press_text_in(pause, tr("settings.back"))
	await _frames(10)
	await _press_text_in(pause, tr("settings.back"))
	await _frames(10)
	await _press_text_in(pause, tr("pause.resume"))
	await _frames(20)


## The real Hint button on an empty pile, so its pencilled ticks show (ADR 0035); the
## tour's own hint may have been a pass. A turn whose hint marks nothing is left for a
## later one. The selection is cleared after, so the walk plays its own choice.
func hint_cards_frame(table: Node, where: String) -> void:
	var pile: Node = member(table, "_pile")
	if int(pile.call("play_count")) > 0:
		return
	var hand: Object = app.get("hand")
	hand.call("clear")
	await _frames(2)
	var actions: Object = table.call("actions")
	await _press(actions.get("hint"))
	await _frames(20)
	var ticked: Array = hand.call("selected_ids")
	if ticked.is_empty():
		# No play suggested this turn: a later lead is tried.
		print("HINT no cards %s" % where)
		return
	hint_shot = true
	await _shot("tour_hint_cards")
	hand.call("clear")
	await _frames(4)


## The fan must show exactly the cards the player holds, each once.
func check_fan(table: Node, where: String) -> void:
	var held: Array = view(_controller(), "table").call("player_cards")
	var views: Array = member(member(table, "_hand_view"), "_views")
	var shown: Dictionary[int, bool] = {}
	for view: Control in views:
		if view.visible:
			shown[int(view.get("card_id"))] = true
	if shown.size() != held.size() or views.size() != held.size():
		_fail("FAN MISMATCH %s: holds %d, shows %d" % [where, held.size(), shown.size()])


## Menu, Return to title, then Continue: the run must pick up on the same bid.
func leave_and_continue(table: Node) -> void:
	var hud: Object = member(table, "_hud")
	await _press(hud.get("menu"))
	await _frames(20)
	await _press_text_in(member(table, "_pause"), tr("pause.to_title"))
	await _frames(30)
	await _shot("resume_title")
	await _click_button_with_text(tr("title.continue"))
	await _frames(40)
	await _shot("resume_table")
	var awaiting: int = _controller().call("awaiting")
	if awaiting != AWAIT_BID:
		_fail("RESUME WRONG STATE %d" % awaiting)


## Photographs the audit dice as they tumble and once they have settled, when the bowl
## drops in after a claim; the claims on the slip come first, a step apart.
func dice_frames(table: Node, round_number: int) -> void:
	var moments: Object = member(table, "_moments")
	# Held weakly: under reduced motion the round can end and take the table with it
	# before the dice are looked at, and a gone bowl rolls no more.
	var bowl: WeakRef = weakref(moments.get("dice"))
	var rolling: Callable = func() -> bool:
		var held: Object = bowl.get_ref()
		return held != null and bool(held.call("is_rolling"))
	if not await _until(rolling, 4.0):
		return
	for frame: int in 3:
		await _snap("round%d_dice_roll_%d" % [round_number, frame])
	if not await _until(func() -> bool: return not bool(rolling.call())):
		_fail("DICE NEVER SETTLED round %d" % round_number)
	await _snap("round%d_dice_settled" % round_number)


## On the first turn after a Campaign was bought, in a sandbox put back after: the tray
## holding two leaflets, Model Harvest armed with cards chosen, its rosettes pressed on,
## Registration Drive's chops after it, a court card among the marked, and then the tray
## alone at the last corruption stage (the table's own art keeps the stage it was drawn
## at, so the frame is named for the tray). The Campaigns are handed over through the
## run's state, which only this development tool does; then the save taken before is
## written back and resumed, so the run and its record go on as they were.
func campaign_turn(table: Node) -> void:
	var loop: RunLoop = _loop()
	var snapshot: Dictionary = loop.record.to_dict()
	loop.state.inventory.consumables.assign(["model_harvest", "registration_drive"])
	var campaigns: Object = member(table, "_campaigns")
	campaigns.call("refresh")
	var tray: Object = campaigns.get("tray")
	await _shot("table_campaign_tray")
	var chosen: Array[int] = _marking_picks(2, [])
	await _arm_and_choose(table, tray, chosen)
	await _shot("table_campaign_armed")
	await _press(tray.get("use"))
	for frame: int in 4:
		await _snap("table_campaign_marking_%d" % frame)
	await tree.create_timer(2.0).timeout
	await _arm_and_choose(table, tray, _marking_picks(3, chosen))
	await _press(tray.get("use"))
	await tree.create_timer(2.0).timeout
	await _shot("table_campaign_marked")
	var was: int = ArtStages.stage_override
	ArtStages.stage_override = LAST_STAGE
	loop.state.inventory.consumables.assign(["grain_loan", "anonymous_letter"])
	campaigns.call("refresh")
	for node: Node in table.find_children("*", "CanvasItem", true, false):
		(node as CanvasItem).queue_redraw()
	await _shot("table_campaign_tray_stage_9")
	ArtStages.stage_override = was
	await _restore(snapshot)


## Arms the tray's first leaflet and clicks the cards for it.
func _arm_and_choose(table: Node, tray: Object, card_ids: Array[int]) -> void:
	await _mouse_click(tray.call("slot_center", 0))
	for card_id: int in card_ids:
		await _click_card(table, card_id)


## Up to count cards of the hand to mark, court cards first, none of them already taken
## and none already marked: a Campaign refuses a card that carries its mark, and the marks
## walk may have marked this hand.
func _marking_picks(count: int, taken: Array[int]) -> Array[int]:
	var hand: Object = app.get("hand")
	var cards: Array = hand.call("cards")
	var picks: Array[int] = []
	var court: Array[int] = [Ranks.JACK, Ranks.QUEEN, Ranks.KING]
	for want_court: bool in [true, false]:
		for card: CardInstance in cards:
			if picks.size() >= count or taken.has(card.id()) or picks.has(card.id()):
				continue
			if _is_marked(card):
				continue
			if court.has(card.base_rank()) == want_court:
				picks.append(card.id())
	return picks


func _is_marked(card: CardInstance) -> bool:
	return (
		card.enhancement_id() != CardInstance.NO_ID or card.owner_stamp() != CardInstance.NO_OWNER
	)


## Plays the table's big moments by hand and photographs each a few frames apart, so
## their look can be checked without watching them move.
func _moment_frames(table: Node) -> void:
	var moments: Object = member(table, "_moments")
	var callout: Object = moments.get("callout")
	var face: Texture2D = app.call("seat_portrait", 1, Vector2.ONE)
	var red: Color = Color("b02a17")
	callout.call("shout", "Call!", 0, red, "Wang calls the landlord seat", face, false)
	for frame: int in 4:
		await _snap("moment_cut_in_%d" % frame)
	await tree.create_timer(2.0).timeout
	callout.call("shout", "Bomb!", 1, red, "Zhao", null, true)
	for frame: int in 4:
		await _snap("moment_takeover_%d" % frame)
	await tree.create_timer(2.0).timeout
	invoke(moments, "_show_kitty", [1, [3, 20, 51] as Array[int]])
	for frame: int in 3:
		await _snap("moment_kitty_%d" % frame)
	await tree.create_timer(2.0).timeout
	var hud: Object = member(table, "_hud")
	hud.call("add_progress", 1600.0, 0.0)
	callout.call("shout", "Quota met", 1, red, "1.6K of 1.5K work points", null, true)
	for frame: int in 3:
		await _snap("moment_quota_%d" % frame)
	await tree.create_timer(2.0).timeout
	var controller: Object = _controller()
	hud.call("sync", controller.call("state_copy"), view(controller, "figures").call("target"))
	var tally: Object = moments.get("tally")
	tally.call("show_score", 54.0, 7.0, 1.5, 567.0, 1.0)
	for frame: int in 4:
		await _snap("moment_tally_%d" % frame)
	await tree.create_timer(2.0).timeout
	# The same sum acted out as a play scores: the cards' Grain, the Rate and Zeal landing,
	# a change to Zeal firing with its tag, then the total rolling and stamped.
	var scored: RunEvent = RunEvent.new(RunEvent.Type.PLAY_SCORED, 0, 0, 567.0)
	scored.grain = 54.0
	scored.rate = 7.0
	scored.zeal = 1.5
	var sequence: Object = moments.get("sequence")
	sequence.call("play", scored, 1.0)
	for frame: int in 8:
		await _snap("moment_score_%d" % frame)
	await tree.create_timer(2.0).timeout
	await _bowl_frames(table)


## The dice bowl settled on a 1 and a 4, so the red 1 and its audit ring show, at each of
## BOWL_STAGES. The stage override is put back after.
func _bowl_frames(table: Node) -> void:
	var moments: Object = member(table, "_moments")
	var bowl: Object = moments.get("dice")
	var seats: Array[int] = [1, 2]
	var faces: Array[int] = [1, 4]
	var names: Array[String] = ["Wang", "Zhao"]
	var was: int = ArtStages.stage_override
	for stage: int in BOWL_STAGES:
		ArtStages.stage_override = stage
		var seconds: float = float(bowl.call("roll", seats, faces, 1, names))
		await tree.create_timer(seconds + 0.2).timeout
		await _snap("moment_bowl_stage_%d" % stage)
		bowl.call("dismiss")
	ArtStages.stage_override = was


## Under reduced motion the arrival's slip refuses a click with a red border and a cross
## for 0.6 s in place of a pulse (ADR 0035). The demo skips the arrival, so the slip is
## staged over the table with one of its lines, refuses once, and is taken inside that
## time.
func _refusal_frame() -> void:
	if not options.has(DisplayFlags.REDUCED_MOTION):
		return
	var script: GDScript = load("res://ui/tutorial/tutorial_slip.gd")
	var slip: Control = script.new()
	tree.root.add_child(slip)
	var face: Vector2 = script.get_script_constant_map()["FACE"]
	slip.call("set_face", app.call("seat_portrait", 1, face))
	slip.call("say", tr("tutorial.step.02.say"))
	await _frames(2)
	var avoid: Array[Rect2] = []
	slip.call("place", Rect2(Vector2(1300, 880), Vector2(240, 60)), avoid, Vector2(1920, 1080))
	await _frames(2)
	slip.call("refuse")
	if not bool(slip.call("shows_cross")):
		_fail("the slip showed no cross under reduced motion")
	await _snap("tutorial_refused_reduced")
	slip.queue_free()
	await _frames(2)
