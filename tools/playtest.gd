# gdlint: disable=max-file-lines
# Over 400 lines: one script walks every screen and moment the playtest photographs.
extends SceneTree
## Plays the demo through its real UI, the way a person would: clicks the visible part of
## each card with mouse events, presses Play, Pass, Call and the store's buttons, and goes
## through several rounds and Sets. Logs any click that selects the wrong card or does
## nothing, and saves a screenshot at each round's first turn and every few turns.
##   godot --path . --script res://tools/playtest.gd -- --rounds 6 --out reports/playtest
## Needs a real window. Development only; tools/ never ships.

const SEED: int = 4242
const SHOT_EVERY: int = 5
const STEP_FRAMES: int = 4
const SETTLE_SECONDS: float = 1.2
## Seconds between pictures of a moment in motion.
const SNAP_SECONDS: float = 0.22
const SAVE_PATH: String = "user://playtest/run.json"
## The Campaigns that mark cards, one of which the table photographs in use.
const MARKING: Array[String] = ["model_harvest", "registration_drive"]
## Corruption stages the dice bowl is photographed at, settled on a 1 and a 4.
const BOWL_STAGES: Array[int] = [0, 3, 6, 9]

var _out: String = "res://reports/playtest"
var _rounds_wanted: int = 6
var _app: Node
var _shots: int = 0
var _misclicks: int = 0
var _clicks: int = 0
var _rounds_seen: int = 0
var _turns_in_round: int = 0
var _driver: Object
var _toured: bool = false
var _resumed: bool = false
var _bought: int = 0
var _issued: bool = false
var _campaign_bought: bool = false
var _campaign_used: bool = false
var _opening_shot: bool = false


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for flag: String in ["--out", "--rounds"]:
		var at: int = args.find(flag)
		if at >= 0 and at + 1 < args.size():
			if flag == "--out":
				_out = "res://" + args[at + 1]
			else:
				_rounds_wanted = int(args[at + 1])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_run.call_deferred()


func _run() -> void:
	# Loaded at run time: the demo names autoloads, which a --script tool can't see.
	var saves: Node = root.get_node("Saves")
	saves.call("use_run_path", SAVE_PATH)
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = scene.instantiate()
	root.add_child(_app)
	var script: GDScript = load("res://tests/unit/controller_script.gd")
	_driver = script.new()
	await _frames(20)
	var switcher: Object = _app.get("switcher")
	if switcher.call("current_id") == "content_note":
		await _shot("content_note")
		await _click_button_with_text(tr("note.continue"))
		await _frames(20)
	await _shot("title")
	await _click_button_with_text(tr("title.new_run"))
	await _frames(30)
	await _shot("run_setup")
	await _click_button_with_text(tr("setup.start"))
	await _frames(30)
	await _shot("set_intro")
	await _click_button_with_text(tr("intro.begin"))
	var guard: int = 0
	while _rounds_seen <= _rounds_wanted and guard < 3000:
		guard += 1
		await _frames(STEP_FRAMES)
		await _step()
	print("rounds=%d clicks=%d misclicks=%d shots=%d" % [_rounds_seen, _clicks, _misclicks, _shots])
	quit(0)


func _step() -> void:
	var switcher: Object = _app.get("switcher")
	var screen_id: String = switcher.call("current_id")
	match screen_id:
		"table":
			await _table_step()
		"set_summary":
			await _shot("set_summary")
			await _click_first_button()
		"store":
			await _shot("store")
			await _buy_one()
			await _issue_one()
			await _buy_campaign()
			await _click_button_with_text(tr("market.open"))
			await _shot("black_market")
			await _click_button_with_text(tr("market.back"))
			await _click_button_with_text(tr("store.leave"))
		"set_intro":
			await _shot("set_intro")
			await _click_button_with_text(tr("intro.begin"))
		"year_summary":
			await _shot("year_summary")
			await _click_first_button()
		"demo_complete":
			await _shot("demo_complete")
			_rounds_seen = _rounds_wanted + 1


func _table_step() -> void:
	var switcher: Object = _app.get("switcher")
	var table: Node = switcher.call("current")
	var events: Node = table.get("_player")
	if not events.call("is_idle"):
		return
	var controller: Node = _app.get("controller")
	var awaiting: int = controller.call("awaiting")
	match awaiting:
		1:
			_rounds_seen += 1
			_turns_in_round = 0
			await _shot("round%d_bid" % _rounds_seen)
			if _rounds_seen == 3 and not _resumed:
				_resumed = true
				await _leave_and_continue(table)
				return
			var bid_bar: Object = table.call("actions")
			await _press(bid_bar.get("decline"))
			if _rounds_seen <= 2:
				await _frames(5)
				await _shot("round%d_bid_stamps" % _rounds_seen)
		4:
			var need_panel: Node = table.call("need_panel")
			var declare: Button = need_panel.get("_declare")
			var more: Button = need_panel.get("_more")
			await _press(more)
			await _frames(6)
			await _shot("round%d_need" % _rounds_seen)
			await _press(declare)
			await _dice_frames(table)
			await _shot("round%d_audit" % _rounds_seen)
		3:
			await _play_turn(table, controller)
		9:
			# The opening before the first play, when a held Campaign could be used.
			if not _opening_shot:
				_opening_shot = true
				await _shot("round%d_opening" % _rounds_seen)
			var opening_bar: Object = table.call("actions")
			await _press(opening_bar.get("play_on"))


func _play_turn(table: Node, controller: Node) -> void:
	_turns_in_round += 1
	if _turns_in_round == 1 or _turns_in_round % SHOT_EVERY == 0:
		await _shot("round%d_turn%d" % [_rounds_seen, _turns_in_round])
	_check_fan(table, controller)
	if not _toured:
		_toured = true
		await _tour(table)
	if _campaign_bought and not _campaign_used:
		_campaign_used = true
		await _campaign_turn(table, controller)
		return
	var ids: Array[int] = _driver.call("choose_play", controller)
	var actions: Object = table.call("actions")
	if ids.is_empty():
		await _press(actions.get("pass_turn"))
		return
	var hand: Object = _app.get("hand")
	for card_id: int in ids:
		await _click_card(table, card_id)
		_clicks += 1
		if not hand.call("is_selected", card_id):
			_misclicks += 1
			print("MISCLICK round %d turn %d card %d" % [_rounds_seen, _turns_in_round, card_id])
	await _frames(2)
	var play: Button = actions.get("play")
	if play.disabled:
		var reading: Label = actions.get("reading")
		print("PLAY DISABLED round %d turn %d: %s" % [_rounds_seen, _turns_in_round, reading.text])
		for card_id: int in ids:
			hand.call("set_selected", card_id, true)
	await _press(play)


## Buys the first Cadre the store will sell, and photographs the store after.
func _buy_one() -> void:
	var switcher: Object = _app.get("switcher")
	var screen: Node = switcher.call("current")
	for child: Node in screen.find_children("*", "Button", true, false):
		var button: Button = child as Button
		if button.theme_type_variation == "CouponButton" and not button.disabled:
			# The seal as it lands on a card, pressed by hand so it can be photographed.
			var seal: Control = screen.get("_seal")
			var counter: Control = screen.get("_counter")
			var card: Control = counter.get_child(0)
			seal.position = card.global_position + card.size / 2.0 - seal.size / 2.0
			seal.call("press")
			await _snap("store_seal")
			seal.hide()
			await _press(button)
			for frame: int in 3:
				await _snap("store_buying_%d" % frame)
			await _frames(30)
			_bought += 1
			await _shot("store_bought")
			return


## Photographs the Directive column, its "Issued" seal pressed by hand on the first
## document, then issues the first Directive the coupons allow and photographs the seal,
## the Rates ticking and the document leaving. Once a run.
func _issue_one() -> void:
	if _issued:
		return
	var switcher: Object = _app.get("switcher")
	var screen: Node = switcher.call("current")
	var row: Control = screen.get("_directives")
	if row == null or row.get_child_count() < 2:
		return
	_issued = true
	await _shot("store_directives")
	for child: Node in row.find_children("*", "Button", true, false):
		var button: Button = child as Button
		if button.theme_type_variation == "CouponButton" and not button.disabled:
			await _press(button)
			for frame: int in 5:
				await _snap("store_issuing_%d" % frame)
			await _frames(30)
			await _shot("store_issued")
			return


## Buys the state store's Campaign and photographs its leaflet flying into the tray on
## the shelf. Once a run.
func _buy_campaign() -> void:
	if _campaign_bought:
		return
	var switcher: Object = _app.get("switcher")
	var screen: Node = switcher.call("current")
	var stall: Object = screen.get("_campaign_stall")
	var offers: Control = stall.get("_offers")
	for child: Node in offers.find_children("*", "Button", true, false):
		var button: Button = child as Button
		if not button.disabled:
			await _shot("store_campaign_offer")
			await _press(button)
			for frame: int in 3:
				await _snap("store_campaign_buying_%d" % frame)
			await _frames(30)
			_campaign_bought = true
			await _shot("store_campaign_tray")
			return


## On the first turn after a Campaign was bought: the tray, a marking Campaign armed with
## two cards chosen, the marks pressed on, and the marked hand. The store sells whatever
## it draws, so when the bought one marks no cards this hands the player a Model Harvest
## through the run's state, which only this development tool does.
func _campaign_turn(table: Node, controller: Node) -> void:
	var held: Array = controller.call("held_campaigns")
	var slot: int = -1
	for index: int in held.size():
		if MARKING.has(held[index]):
			slot = index
	if slot < 0:
		var loop: Object = controller.get("_loop")
		var state: Object = loop.get("state")
		var inventory: Object = state.get("inventory")
		var consumables: Array[String] = inventory.get("consumables")
		if consumables.size() >= int(controller.call("campaign_slots")):
			consumables.pop_back()
		consumables.append("model_harvest")
		slot = consumables.size() - 1
		var campaigns_now: Object = table.get("_campaigns")
		campaigns_now.call("refresh")
	var campaigns: Object = table.get("_campaigns")
	var tray: Object = campaigns.get("tray")
	await _shot("table_campaign_tray")
	await _mouse_click(tray.call("slot_center", slot))
	var hand: Object = _app.get("hand")
	var cards: Array = hand.call("cards")
	for index: int in mini(2, cards.size()):
		var card: CardInstance = cards[index]
		await _click_card(table, card.id())
	await _shot("table_campaign_armed")
	await _press(tray.get("use"))
	for frame: int in 4:
		await _snap("table_campaign_marking_%d" % frame)
	await create_timer(2.0).timeout
	await _shot("table_campaign_marked")


## The dice bowl settled on a 1 and a 4, so the red 1 and its audit ring show, at
## corruption stages 0, 3, 6 and 9. The stage override is put back after.
func _bowl_frames(table: Node) -> void:
	var moments: Object = table.get("_moments")
	# Named by Object: a UI class named here fails to compile when the tool runs with --script.
	var bowl: Object = moments.get("dice")
	var seats: Array[int] = [1, 2]
	var faces: Array[int] = [1, 4]
	var names: Array[String] = ["Wang", "Zhao"]
	var was: int = ArtStages.stage_override
	for stage: int in BOWL_STAGES:
		ArtStages.stage_override = stage
		var seconds: float = float(bowl.call("roll", seats, faces, 1, names))
		await create_timer(seconds + 0.2).timeout
		await _snap("moment_bowl_stage_%d" % stage)
		bowl.call("dismiss")
	ArtStages.stage_override = was


## Menu, Return to title, then Continue: the run must pick up on the same bid.
func _leave_and_continue(table: Node) -> void:
	var hud: Object = table.get("_hud")
	await _press(hud.get("menu"))
	await _frames(20)
	var pause: Node = table.get("_pause")
	await _press(_button_in(pause, tr("pause.to_title")))
	await _frames(30)
	await _shot("resume_title")
	await _click_button_with_text(tr("title.continue"))
	await _frames(40)
	await _shot("resume_table")
	var controller: Node = _app.get("controller")
	if controller.call("awaiting") != 1:
		_misclicks += 1
		print("RESUME WRONG STATE %d" % controller.call("awaiting"))


## Photographs the audit dice as they tumble and once they have settled, when the bowl
## drops in after a claim; the claims on the slip come first, a step apart.
func _dice_frames(table: Node) -> void:
	var moments: Object = table.get("_moments")
	var bowl: Object = moments.get("dice")
	var waited: int = 0
	while not bool(bowl.call("is_rolling")) and waited < 240:
		await _frames(1)
		waited += 1
	if not bool(bowl.call("is_rolling")):
		return
	for frame: int in 3:
		await _snap("round%d_dice_roll_%d" % [_rounds_seen, frame])
	while bool(bowl.call("is_rolling")):
		await _frames(1)
	await _snap("round%d_dice_settled" % _rounds_seen)


## Plays the table's big moments by hand and photographs each a few frames apart, so
## their look can be checked without watching them move.
func _moment_frames(table: Node) -> void:
	var moments: Object = table.get("_moments")
	var callout: Object = moments.get("callout")
	var face: Texture2D = _app.call("seat_portrait", 1, Vector2.ONE)
	var red: Color = Color("b02a17")
	callout.call("shout", "Call!", 0, red, "Wang calls the landlord seat", face, false)
	for frame: int in 4:
		await _snap("moment_cut_in_%d" % frame)
	await create_timer(2.0).timeout
	callout.call("shout", "Bomb!", 1, red, "Zhao", null, true)
	for frame: int in 4:
		await _snap("moment_takeover_%d" % frame)
	await create_timer(2.0).timeout
	moments.call("_show_kitty", 1, [3, 20, 51] as Array[int])
	for frame: int in 3:
		await _snap("moment_kitty_%d" % frame)
	await create_timer(2.0).timeout
	var hud: Object = table.get("_hud")
	hud.call("add_progress", 1600.0, 0.0)
	callout.call("shout", "Quota met", 1, red, "1.6K of 1.5K work points", null, true)
	for frame: int in 3:
		await _snap("moment_quota_%d" % frame)
	await create_timer(2.0).timeout
	var controller: Node = _app.get("controller")
	hud.call("sync", controller.call("state_copy"), controller.call("target"))
	var tally: Object = moments.get("tally")
	tally.call("show_score", 54.0, 7.0, 1.5, 567.0, 1.0)
	for frame: int in 4:
		await _snap("moment_tally_%d" % frame)
	await create_timer(2.0).timeout
	await _bowl_frames(table)


## Presses every table control once and photographs the result.
func _tour(table: Node) -> void:
	await _moment_frames(table)
	var actions: Object = table.call("actions")
	for mode: int in 3:
		await _press(actions.get("sort"))
		await _frames(30)
		await _shot("tour_sort%d" % mode)
	await _press(actions.get("hint"))
	await _frames(20)
	await _shot("tour_hint")
	var hand: Object = _app.get("hand")
	hand.call("clear")
	await _press(actions.get("rules"))
	await _frames(30)
	await _shot("tour_rules")
	await _mouse_click(Vector2(60, 1040))
	await _frames(10)
	var hud: Object = table.get("_hud")
	await _press(hud.get("menu"))
	await _frames(30)
	await _shot("tour_menu")
	var pause: Node = table.get("_pause")
	await _press(_button_in(pause, tr("pause.settings")))
	await _frames(30)
	await _shot("tour_menu_settings")
	await _press(_button_in(pause, tr("settings.back")))
	await _frames(10)
	await _press(_button_in(pause, tr("pause.resume")))
	await _frames(20)


func _button_in(root_node: Node, text: String) -> Button:
	for child: Node in root_node.find_children("*", "Button", true, false):
		var button: Button = child as Button
		if button.text == text and button.is_visible_in_tree():
			return button
	print("NO BUTTON '%s'" % text)
	return null


## The fan must show exactly the cards the player holds, each once.
func _check_fan(table: Node, controller: Node) -> void:
	var held: Array = controller.call("player_cards")
	var hand_view: Control = table.get("_hand_view")
	var views: Array = hand_view.get("_views")
	var shown: Dictionary = {}
	for view: Control in views:
		if view.visible:
			shown[view.get("card_id")] = true
	if shown.size() != held.size() or views.size() != held.size():
		_misclicks += 1
		print(
			(
				"FAN MISMATCH round %d turn %d: holds %d, shows %d"
				% [_rounds_seen, _turns_in_round, held.size(), shown.size()]
			)
		)


## Clicks the strip of the card that the next card in the fan leaves showing.
func _click_card(table: Node, card_id: int) -> void:
	var hand_view: Control = table.get("_hand_view")
	var views: Array = hand_view.get("_views")
	for index: int in views.size():
		var view: Control = views[index]
		if view.get("card_id") != card_id:
			continue
		var visible_x: float = 24.0
		if index == views.size() - 1:
			visible_x = view.size.x / 2.0
		var local: Vector2 = Vector2(visible_x, view.size.y * 0.45)
		await _mouse_click(view.get_global_transform_with_canvas() * local)
		return
	print("CARD NOT IN FAN %d" % card_id)


func _press(button: Button) -> void:
	if button == null or not button.is_visible_in_tree():
		return
	await _mouse_click(button.get_global_transform_with_canvas() * (button.size / 2.0))


func _press_node(panel: Node) -> void:
	for child: Node in panel.find_children("*", "Button", true, false):
		await _press(child as Button)
		return


func _click_first_button() -> void:
	var switcher: Object = _app.get("switcher")
	var screen: Node = switcher.call("current")
	for child: Node in screen.find_children("*", "Button", true, false):
		var button: Button = child as Button
		if button.is_visible_in_tree() and not button.disabled:
			await _press(button)
			return


func _click_button_with_text(text: String) -> void:
	var switcher: Object = _app.get("switcher")
	var screen: Node = switcher.call("current")
	await _frames(5)
	for child: Node in screen.find_children("*", "Button", true, false):
		var button: Button = child as Button
		if button.text == text:
			await _press(button)
			await _frames(20)
			return
	print("NO BUTTON '%s'" % text)


func _mouse_click(at: Vector2) -> void:
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.position = at
	root.push_input(move, true)
	await _frames(1)
	for pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = at
		root.push_input(click, true)
		await _frames(1)


func _frames(count: int) -> void:
	for _frame: int in count:
		await process_frame


## A picture of a moment in motion: a short beat on, with no wait for things to settle.
func _snap(name: String) -> void:
	await create_timer(SNAP_SECONDS).timeout
	await RenderingServer.frame_post_draw
	_shots += 1
	var path: String = _out.path_join("%02d_%s.png" % [_shots, name])
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))


func _shot(name: String) -> void:
	# Count-ups and entrances run on the clock, and software rendering is slow, so wait
	# on time, not frames, before a picture.
	await create_timer(SETTLE_SECONDS).timeout
	await RenderingServer.frame_post_draw
	_shots += 1
	var path: String = _out.path_join("%02d_%s.png" % [_shots, name])
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
