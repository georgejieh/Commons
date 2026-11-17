# gdlint: disable=max-file-lines
# Over 400 lines: one script walks every screen and moment the playtest photographs.
extends SceneTree
## Plays the demo through its real UI, the way a person would: clicks the visible part of
## each card with mouse events, presses Play, Pass, Call and the store's buttons, and goes
## through several rounds and Sets. Logs any click that selects the wrong card or does
## nothing, and saves a screenshot at each round's first turn and every few turns. It
## starts the app as --demo does, so New Run is the demo, and at the end starts a full
## run once for its frames (ADR 0025).
##   godot --path . --script res://tools/playtest.gd -- --demo --rounds 6 --out reports/playtest
## With --tutorial in place of --demo it plays the arrival instead (ADR 0026), from a
## first launch with no profile to run setup, through tools/tutorial_walk.gd:
##   godot --path . --script res://tools/playtest.gd -- --tutorial --out reports/tutorial
## Needs a real window for its pictures. Run with --headless it walks the same steps and
## prints each frame's name instead, which checks its clicks without a window.
## Development only; tools/ never ships.

const SEED: int = 4242
const SHOT_EVERY: int = 5
const STEP_FRAMES: int = 4
## Steps the walk may stand on one page other than the table before it is stuck.
const STUCK_STEPS: int = 40
## Steps the whole walk may take before it is failed as never ending.
const WALK_STEPS: int = 3000
const SETTLE_SECONDS: float = 1.2
## Seconds between pictures of a moment in motion.
const SNAP_SECONDS: float = 0.22
## The longest a wait on something the table does may take, in real seconds: generous,
## since a headless run and a software-rendered one go at different paces.
const WAIT_SECONDS: float = 20.0
## The profile corruption values the table is photographed at: stages 0, 3, 6 and 9.
const CORRUPTION_VALUES: Array[int] = [5, 35, 65, 95]
## How many rounds the Night Shift sandbox's Quota may run, so its refusal comes.
const NIGHT_SHIFT_ROUNDS: int = 12
const SAVE_PATH: String = "user://playtest/run.json"
## Corruption stages the dice bowl is photographed at, settled on a 1 and a 4.
const BOWL_STAGES: Array[int] = [0, 3, 6, 9]
## Each ending and death the playtest finishes a run on (ADR 0024): Famine, Denunciation,
## Resentment and rounds as landlord of the final Year's four.
const ENDING_RUNS: Dictionary[String, Array] = {
	"secret_contract": [30, 20, 40, 0],
	"the_commons": [10, 10, 0, 0],
	"lean_years": [80, 20, 40, 1],
	"labeled": [20, 80, 40, 1],
	"benevolent_landlord": [30, 30, 40, 3],
	"full_granary": [85, 40, 40, 4],
	"struggled": [40, 90, 40, 2],
	"death_famine": [100, 40, 40, 1],
	"death_denunciation": [40, 100, 40, 1],
}

var _out: String = "res://reports/playtest"
var _rounds_wanted: int = 6
var _app: Node
var _shots: int = 0
var _misclicks: int = 0
## The page the walk stands on and for how many steps, for _stuck().
var _stood_on: String = ""
var _stood_steps: int = 0
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
var _market_shot: bool = false
var _opening_granted: bool = false
var _reform_shot: bool = false
var _envelope_shot: bool = false
var _parcel_shot: bool = false
var _debuffs_shot: bool = false
var _wild_store_shot: bool = false
var _file_store_shot: bool = false
## No window to photograph: frames are named, not saved.
var _headless: bool = false
## True for the arrival's own short run (--tutorial).
var _tutorial: bool = false


func _initialize() -> void:
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		# Paced like a window, so the step guard lasts as long as the moments it waits on.
		Engine.max_fps = 60
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_tutorial = args.has("--tutorial")
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
	if _tutorial:
		await _tutorial_run()
		return
	# Loaded at run time: the demo names autoloads, which a --script tool can't see.
	var saves: Node = root.get_node("Saves")
	saves.call("use_run_path", SAVE_PATH)
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = scene.instantiate()
	# The demo flow, as --demo on the command line gives it, whether or not it was passed.
	_app.set("demo", true)
	root.add_child(_app)
	var script: GDScript = load("res://tests/unit/controller_script.gd")
	_driver = script.new()
	await _frames(20)
	var switcher: Object = _app.get("switcher")
	if switcher.call("current_id") == "content_note":
		await _shot("content_note")
		await _click_button_with_text(tr("note.continue"))
		await _frames(20)
	# With no profile the family's name comes first (ADR 0028): the default is taken.
	if switcher.call("current_id") == "surname":
		var naming: Node = switcher.call("current")
		await _press(naming.call("confirm_button"))
		await _frames(20)
	# With no profile the arrival is offered first (ADR 0026); the demo skips it.
	if switcher.call("current_id") == "arrival":
		await _click_button_with_text(tr("tutorial.skip"))
		var page: Node = switcher.call("current")
		var confirm: Object = page.call("confirm")
		await _press(confirm.call("skip_button"))
		await _frames(20)
	await _shot("title")
	await _collection_frames()
	await _click_button_with_text(tr("title.new_run"))
	await _frames(30)
	await _shot("run_setup")
	await _click_button_with_text(tr("setup.start"))
	await _frames(30)
	await _shot("set_intro")
	await _slogan_frame()
	await _click_button_with_text(tr("intro.begin"))
	var guard: int = 0
	while _rounds_seen <= _rounds_wanted and guard < WALK_STEPS:
		guard += 1
		await _frames(STEP_FRAMES)
		if _stuck():
			quit(1)
			return
		await _step()
	await _ending_frames()
	await _full_run_frames()
	# Headless, frames outrun the table's animations and the steps run out first: only a
	# walk on a display is failed for it.
	if guard >= WALK_STEPS and _rounds_seen <= _rounds_wanted and not _headless:
		_misclicks += 1
		print("MISCLICK the walk ran out of steps after %d rounds" % _rounds_seen)
	print("rounds=%d clicks=%d misclicks=%d shots=%d" % [_rounds_seen, _clicks, _misclicks, _shots])
	quit(1 if _misclicks > 0 else 0)


## The arrival on its own (ADR 0026), walked by tools/tutorial_walk.gd.
func _tutorial_run() -> void:
	var script: GDScript = load("res://tools/tutorial_walk.gd")
	var walk: Object = script.new()
	await walk.call("run", self, _out, _headless)
	var counts: Array = [walk.get("shots"), walk.get("clicks"), walk.get("misclicks")]
	print("tutorial shots=%d clicks=%d misclicks=%d" % counts)
	quit(1 if int(counts[2]) > 0 else 0)


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
			await _file_store_frames()
			await _wild_store_frames()
			await _reform_frames()
			await _buy_one()
			await _issue_one()
			await _buy_campaign()
			await _envelope_frames()
			await _click_button_with_text(tr("market.open"))
			await _shot("black_market")
			await _parcel_frames()
			# The Parcel's sandbox resumes the saved run, which lands in the state store.
			if switcher.call("current_id") != "black_market":
				await _click_button_with_text(tr("market.open"))
			await _market_frames()
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
			if not _opening_granted:
				_grant_opening()
			await _shot("round%d_bid" % _rounds_seen)
			if _rounds_seen == 3 and not _resumed:
				_resumed = true
				await _leave_and_continue(table)
				return
			if _rounds_seen == 2 and not _debuffs_shot:
				_debuffs_shot = true
				await _debuff_frames()
				await _wild_table_frames()
				await _file_table_frames()
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
			_fail("MISCLICK round %d turn %d card %d" % [_rounds_seen, _turns_in_round, card_id])
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


## The collection from the title: both grids, then scrolled to its last card by focus,
## as a gamepad would.
func _collection_frames() -> void:
	await _click_button_with_text(tr("title.collection"))
	await _frames(30)
	await _shot("collection")
	var switcher: Object = _app.get("switcher")
	var screen: Node = switcher.call("current")
	var entries: Array = screen.call("entries")
	if not entries.is_empty():
		var last: Control = entries[-1]
		last.grab_focus()
		await _frames(10)
		await _shot("collection_scrolled")
	await _click_button_with_text(tr("coll.back"))
	await _frames(20)


## In the black market, once a run: the rank picker open over the counter with a ticket
## in focus, then the notice board holding Cadres that show counts, one of them firing.
## The stock, Cadres and counts are handed over through the run's state, which only this
## tool does, and put back after, so the run's record still replays.
func _market_frames() -> void:
	if _market_shot:
		return
	_market_shot = true
	var switcher: Object = _app.get("switcher")
	var screen: Node = switcher.call("current")
	var controller: Node = _app.get("controller")
	var loop: Object = controller.get("_loop")
	var state: RunState = loop.get("state")
	var market: Object = loop.get("market")
	var held: Array[String] = state.inventory.cadres.duplicate()
	var memos: Dictionary = state.cadre_memos.to_dict()
	var stock: Array[String] = market.get("_stock")
	var coupons: int = state.coupons
	# One Cadre with art between two without, each with its full rules.
	var offered: Array[String] = ["rehabilitation", "hidden_reserves", "last_sheaf"]
	market.set("_stock", offered)
	state.coupons = maxi(coupons, 40)
	# The coupons are a frame's, put back before any command; the second book is told.
	controller.call("reseal_book")
	screen.call("_refresh")
	await _frames(10)
	await _shot("black_market_cadre_rules")
	var counter: Node = screen.get("_counter")
	await _press_node(counter.get_child(0))
	var picker: Object = screen.get("_picker")
	var chips: Array = picker.call("chips")
	await _shot("black_market_rank_picker")
	if chips.size() > Ranks.SEVEN:
		var seven: Control = chips[Ranks.SEVEN]
		seven.grab_focus()
		await _snap("black_market_rank_focus")
	await _press(picker.get("_cancel"))
	state.inventory.cadres.assign(
		["rehabilitation", "ration_coupon", "seed_grain", "steel_target", "stakhanovite"]
	)
	state.cadre_memos.entry("rehabilitation").put(CadreMemo.RANK, Ranks.SEVEN)
	state.cadre_memos.entry("ration_coupon").put(RationCouponEffect.EARNED, 2)
	state.cadre_memos.entry("seed_grain").put(SeedGrainEffect.MET, 3)
	state.cadre_memos.entry("steel_target").put(SteelTargetEffect.BOMBS, 2)
	state.cadre_memos.entry("stakhanovite").put(StakhanoviteEffect.LONG_STRAIGHTS, 1)
	screen.call("_refresh")
	await _shot("notice_board_counts")
	var board: Object = screen.get("_board")
	board.call("fired", controller, "seed_grain", 3)
	await _snap("notice_board_fired")
	state.inventory.cadres.assign(held)
	state.cadre_memos = CadreMemos.from_dict(memos)
	state.coupons = coupons
	controller.call("reseal_book")
	market.set("_stock", stock)
	screen.call("_refresh")
	await _frames(10)


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


## Buys the state store's Campaign and photographs its offer with the slip that explains
## it, then its leaflet flying into the tray on the board. Coupons for it are handed over
## at the Set's end in the record too, so the purchase still replays. Once a run.
func _buy_campaign() -> void:
	if _campaign_bought:
		return
	var switcher: Object = _app.get("switcher")
	var screen: Node = switcher.call("current")
	var stall: Object = screen.get("_campaign_stall")
	if stall.call("panel", 0) == null:
		return
	_grant_coupons(12)
	screen.call("_refresh")
	await _frames(10)
	var offer: Control = stall.call("panel", 0)
	var buy: Button = offer.get("buy")
	if buy == null or not buy.visible or buy.disabled:
		return
	await _hover(offer)
	await _shot("store_campaign_offer")
	await _press(buy)
	for frame: int in 3:
		await _snap("store_campaign_buying_%d" % frame)
	await _frames(30)
	_campaign_bought = true
	await _shot("store_campaign_tray")


## The state store's Reform, once a run: its decree on the counter with the slip, the
## "Enacted" stamp and its flight, the strip it is pinned to and a pinned slip read out
## by focus. Its coupons are handed over in the record too, so the purchase replays.
func _reform_frames() -> void:
	if _reform_shot:
		return
	var switcher: Object = _app.get("switcher")
	var screen: Node = switcher.call("current")
	var stall: Object = screen.get("_reform_stall")
	if stall == null or stall.call("panel", 0) == null:
		return
	_reform_shot = true
	_grant_coupons(12)
	screen.call("_refresh")
	await _frames(10)
	var offer: Control = stall.call("panel", 0)
	await _hover(offer)
	await _shot("store_reform_offer")
	await _press(offer.get("buy"))
	for frame: int in 4:
		await _snap("store_reform_enacting_%d" % frame)
	# On the clock: the stamp and the flight take longer than a fast frame count.
	await create_timer(1.2).timeout
	await _shot("store_reform_strip")
	var strip: Object = stall.get("strip")
	if int(strip.call("held_count")) > 0:
		var pinned: Control = strip.call("tag", 0)
		pinned.grab_focus()
		await _snap("store_reform_strip_slip")


## The state store's envelope, once a run: its offer with the slip, a few frames through
## the opening beat, the papers at rest, one focused, the same at corruption stage 9 with
## the override put back, and one kept under its seal. The coupons are handed over in the
## record too, so the purchase and the pick replay.
func _envelope_frames() -> void:
	if _envelope_shot:
		return
	var switcher: Object = _app.get("switcher")
	var screen: Node = switcher.call("current")
	var stall: Object = screen.get("_envelope_stall")
	if stall == null or stall.call("panel", 0) == null:
		return
	_envelope_shot = true
	_grant_coupons(8)
	screen.call("_refresh")
	await _frames(10)
	var offer: Control = stall.call("panel", 0)
	await _hover(offer)
	await _shot("store_envelope_offer")
	await _press(offer.get("buy"))
	for frame: int in 4:
		await _snap("envelope_opening_%d" % frame)
	var overlay: Object = stall.call("overlay")
	if overlay == null:
		_fail("ENVELOPE DID NOT OPEN")
		return
	await _settled(overlay)
	await _shot("envelope_choices")
	var papers: Array = overlay.call("papers")
	if papers.size() > 1:
		var second: Object = papers[1]
		var focused: Button = second.get("keep")
		focused.grab_focus()
		await _snap("envelope_choice_focused")
	await _stage_9(overlay, "envelope_choices_stage_9")
	var keep: Button = _first_keep(papers, overlay)
	await _press(keep)
	await create_timer(0.25).timeout
	await _snap("envelope_kept")
	await create_timer(2.6).timeout
	if bool(stall.call("is_busy")):
		_fail("ENVELOPE STILL OPEN")


## The black market's Parcel, once a run, in a sandbox put back after: its offer with
## the slip, then a Parcel holding a private Campaign, a stamped court card and a Model
## card, handed over through the run's state as only this tool does, and the stamped card
## kept. The save taken before is written back and resumed, so the run and its record go
## on as they were.
func _parcel_frames() -> void:
	if _parcel_shot:
		return
	var switcher: Object = _app.get("switcher")
	var screen: Node = switcher.call("current")
	var stall: Object = screen.get("_envelope_stall")
	if stall == null or stall.call("panel", 0) == null:
		return
	_parcel_shot = true
	var controller: Object = _app.get("controller")
	var loop: RunLoop = controller.get("_loop")
	var snapshot: Dictionary = loop.record.to_dict()
	loop.state.coupons += 12
	loop.state.inventory.plot.clear()
	# Handed over by this tool for the frame, so the second book is told (ADR 0022).
	controller.call("reseal_book")
	screen.call("_refresh")
	await _frames(10)
	var offer: Control = stall.call("panel", 0)
	await _hover(offer)
	await _shot("market_parcel_offer")
	await _press(offer.get("buy"))
	await _settled(stall.call("overlay"))
	var handed: Array[EnvelopeItem] = [
		EnvelopeItem.new(EnvelopeDef.Content.CAMPAIGN, "registration_drive"),
		EnvelopeItem.new(EnvelopeDef.Content.STAMPED_CARD, "", Ranks.KING, 1),
		EnvelopeItem.new(EnvelopeDef.Content.MODEL_CARD, "", Ranks.SEVEN, 3),
	]
	loop.market.envelopes.set("_items", handed)
	var first: Node = stall.call("overlay")
	first.queue_free()
	stall.set("_overlay", null)
	stall.call("resume")
	await _frames(10)
	var overlay: Object = stall.call("overlay")
	await _shot("parcel_choices")
	var papers: Array = overlay.call("papers")
	var stamped: Object = papers[1]
	var keep_card: Button = stamped.get("keep")
	await _press(keep_card)
	await create_timer(0.25).timeout
	await _snap("parcel_kept")
	await create_timer(2.6).timeout
	var saves_hub: Object = root.get_node("Saves")
	var saves: Object = saves_hub.call("run_service")
	saves.call("save", snapshot)
	_app.call("resume_to_screen")
	await _frames(30)


## The Set intro with a Slogan of the Week on its ladder, naming Pairs, put there through
## the run's state for the picture and taken off again before the Set begins.
func _slogan_frame() -> void:
	var controller: Object = _app.get("controller")
	var loop: RunLoop = controller.get("_loop")
	var ladder: Array[String] = loop.state.debuff_ladder.duplicate()
	var slogan: int = loop.state.slogan_type
	loop.state.debuff_ladder[1] = "slogan_of_the_week"
	loop.state.slogan_type = Pattern.Type.PAIR
	_app.call("show_screen", "set_intro", true)
	await _shot("set_intro_slogan")
	loop.state.debuff_ladder = ladder
	loop.state.slogan_type = slogan
	_app.call("show_screen", "set_intro", true)
	await _frames(20)


## Each table beat of ADR 0023's debuffs, at a round's bid, in a sandbox put back after:
## the debuff is put in force for the rest of the Quota through the run's state, with the
## Cadres or plot cards it needs, in a Quota no one can meet so the sandbox plays on as
## long as a beat needs; the bid is declined so the round starts after the kitty and the
## beat plays; then the save taken before is written back and resumed.
func _debuff_frames() -> void:
	for debuff_id: String in [
		"levy", "redistribution", "confiscation", "glass_walls", "plot_seized", "night_shift"
	]:
		var controller: Object = _app.get("controller")
		var loop: RunLoop = controller.get("_loop")
		var snapshot: Dictionary = loop.record.to_dict()
		loop.state.inventory.plot.clear()
		if debuff_id == "confiscation":
			loop.state.inventory.cadres.assign(["ration_coupon", "red_banner"])
		if debuff_id == "plot_seized":
			for index: int in 2:
				var card: CardInstance = CardInstance.new(
					loop.state.take_plot_id(), Ranks.KING - index, index, CardInstance.Origin.PLOT
				)
				loop.state.inventory.plot.append(card)
		var params: SetParams = SetConfig.DEFAULT_PARAMS.duplicate()
		params.targets = params.targets.duplicate()
		params.targets.fill(1e9)
		if debuff_id == "night_shift":
			# Night Shift needs a round where the player's first chance to pass meets a play
			# they can beat; a long Quota makes sure one comes.
			params.max_rounds = NIGHT_SHIFT_ROUNDS
			while loop.state.debuff_ladder.size() < NIGHT_SHIFT_ROUNDS:
				loop.state.debuff_ladder.append(RunState.NO_DEBUFF)
		loop.set("_sets", SetConfig.new(params))
		_force_debuff(loop, debuff_id)
		await _debuff_beat(debuff_id, controller)
		var saves_hub: Object = root.get_node("Saves")
		var saves: Object = saves_hub.call("run_service")
		saves.call("save", snapshot)
		_app.call("resume_to_screen")
		await _frames(30)


## ADR 0029's wild ranks at the table, in a sandbox put back after (tools/playtest_wild.gd).
func _wild_table_frames() -> void:
	var walk: Object = _wild_walk()
	await walk.call("table", _driver)
	_took(walk)


## The state store with each of the wild ranks' three items on its counter, once a run.
func _wild_store_frames() -> void:
	if _wild_store_shot:
		return
	_wild_store_shot = true
	var walk: Object = _wild_walk()
	await walk.call("store")
	_took(walk)


## The collection of a profile with three finished runs, at the locked wild tier.
func _wild_collection_frame() -> void:
	var view: CollectionView = CollectionView.for_runs(3)
	var index: int = 0
	var locked: int = -1
	for section: int in view.section_keys().size():
		for sheet: UnlockSheet in view.sheets(section):
			if not sheet.open and locked < 0:
				locked = index
			index += 1
	var walk: Object = _wild_walk()
	await walk.call("collection", locked)
	_took(walk)


## ADR 0022's notice and dark figures at the table, in a sandbox put back after
## (tools/playtest_file.gd).
func _file_table_frames() -> void:
	var walk: Object = _file_walk()
	await walk.call("table")
	_took(walk)


## The shops with raised prices, a dark meter and the small ledger, once a run.
func _file_store_frames() -> void:
	if _file_store_shot:
		return
	_file_store_shot = true
	var walk: Object = _file_walk()
	await walk.call("store")
	_took(walk)


## The title's stamp and the history's page of the file, for a profile with entries.
func _file_meta_frames(profile: SaveService) -> void:
	var walk: Object = _file_walk()
	await walk.call("meta", profile)
	_took(walk)


func _file_walk() -> Object:
	var script: GDScript = load("res://tools/playtest_file.gd")
	return script.new(self, _app, _out, _headless, _shots)


func _wild_walk() -> Object:
	var script: GDScript = load("res://tools/playtest_wild.gd")
	return script.new(self, _app, _out, _headless, _shots)


func _took(walk: Object) -> void:
	_shots = int(walk.get("shots"))
	_misclicks += int(walk.get("misclicks"))


## Puts a debuff in force from the round under way to the Quota's end, as if it had
## arrived with this round. A Set's first round is always clean, so there the stack takes
## it straight and the ladder's next step carries it on.
func _force_debuff(loop: RunLoop, debuff_id: String) -> void:
	var round_index: int = loop.state.round_index
	loop.state.debuff_ladder[maxi(round_index, 1)] = debuff_id
	loop.call("_rebuild_modifiers")
	if round_index >= 1:
		return
	var stack: ModifierStack = loop.get("_stack")
	for definition: ModifierDef in RunLoop.DEFAULT_POOL.debuffs:
		if definition.id == debuff_id:
			loop.campaigns.flags.round_debuff = stack.add(definition, RunLoop.PLAYER)
	loop.debuffs.rebuilt()


func _debuff_beat(debuff_id: String, controller: Object) -> void:
	if debuff_id == "confiscation":
		await _until(_struck_on_board)
		if not _struck_on_board():
			_fail("NO CONFISCATION MARK")
		await _snap("table_confiscation_0")
		await _shot("table_confiscation")
		return
	var before: Array[int] = _beats_now()
	await _decline_bids(controller, debuff_id)
	match debuff_id:
		"levy", "redistribution", "plot_seized":
			if not await _until(_beat_counted.bind(before)):
				_fail("NO BEAT %s" % debuff_id)
				return
			for frame: int in 3:
				await _snap("table_%s_%d" % [debuff_id, frame])
		"glass_walls":
			await _until(_events_idle)
			await _shot("table_glass_walls")
		"night_shift":
			await _night_shift_frame(controller)


## Declines every bid put to the player until the round is in play, each once the bid
## bar shows, waiting on conditions in real seconds.
func _decline_bids(controller: Object, debuff_id: String) -> void:
	var deadline: int = Time.get_ticks_msec() + int(WAIT_SECONDS * 1000.0)
	while int(controller.call("awaiting")) == 1 and Time.get_ticks_msec() < deadline:
		await _until(_decline_ready.bind(controller))
		var actions: Object = _table_part("actions")
		if actions != null and int(controller.call("awaiting")) == 1:
			await _press(actions.get("decline"))
		await _frames(2)
	if int(controller.call("awaiting")) == 1:
		_fail("BID NOT DECLINED %s" % debuff_id)


## True once the bid is no longer the player's, or its bar shows with the table at rest.
func _decline_ready(controller: Object) -> bool:
	if int(controller.call("awaiting")) != 1:
		return true
	var actions: Object = _table_part("actions")
	if actions == null or not _events_idle():
		return false
	var decline: Button = actions.get("decline")
	return decline != null and decline.is_visible_in_tree()


## The table on screen and how many debuff beats it has acted out: [its ID, the count],
## or [0, 0] off the table.
func _beats_now() -> Array[int]:
	var beats: Object = _table_part("_debuff_beats")
	var switcher: Object = _app.get("switcher")
	var screen: Object = switcher.call("current")
	if beats == null:
		return [0, 0]
	return [screen.get_instance_id(), int(beats.get("beats_played"))]


## True once a beat has played since before was taken, on that table or a new one. A beat
## counts when it starts, so one that has already ended is still seen.
func _beat_counted(before: Array[int]) -> bool:
	var now: Array[int] = _beats_now()
	if now[0] == 0:
		return false
	return now[1] > (before[1] if now[0] == before[0] else 0)


## Plays on, round after round, until the player's first chance to pass meets something
## they hold that beats the table, then presses Pass and photographs the refusal. Every
## part of the table is looked up afresh on every turn, as each round builds it anew.
func _night_shift_frame(controller: Object) -> void:
	for _turn: int in 400:
		await _until(_events_idle)
		if not str(controller.call("pass_refusal")).is_empty():
			var actions: Object = _table_part("actions")
			if actions != null:
				await _press(actions.get("pass_turn"))
				await _shot("table_night_shift")
				return
		if not bool(_driver.call("act", controller)):
			await _frames(5)
	_fail("NO NIGHT SHIFT REFUSAL")


## A part of the table now on screen, by its property or method name, or null when the
## screen is not the table.
func _table_part(part: String) -> Object:
	var switcher: Object = _app.get("switcher")
	var screen: Node = switcher.call("current")
	if screen == null or not is_instance_valid(screen) or screen.get("_player") == null:
		return null
	if screen.has_method(part):
		return screen.call(part)
	return screen.get(part)


## True once the table's events have all played, or when the table is not on screen.
func _events_idle() -> bool:
	var events: Object = _table_part("_player")
	return events == null or bool(events.call("is_idle"))


## True while a Cadre on the notice board is struck out for the round.
func _struck_on_board() -> bool:
	var board: Object = _table_part("_board")
	if board == null:
		return false
	for index: int in int(board.call("slot_count")):
		if bool(board.call("is_struck", index)):
			return true
	return false


## Counts a step the tool could not take, with its reason, so the run fails on it.
## True when the walk has stood on one page, not the table, for more steps than any page
## takes: a button it cannot reach, such as one off the screen. Says so as a misclick,
## so the walk fails at once and never runs out its time.
func _stuck() -> bool:
	var switcher: Object = _app.get("switcher")
	var screen_id: String = switcher.call("current_id")
	if screen_id != _stood_on or screen_id == "table":
		_stood_on = screen_id
		_stood_steps = 0
		return false
	_stood_steps += 1
	if _stood_steps <= STUCK_STEPS:
		return false
	print("MISCLICK stuck on %s after %d steps" % [screen_id, _stood_steps])
	return true


func _fail(reason: String) -> void:
	print("MISS %s" % reason)
	_misclicks += 1


## Waits until ready says so, at most seconds of real time, and says whether it did.
## ready looks up what it reads each time, so it never holds a node a new round may free.
func _until(ready: Callable, seconds: float = WAIT_SECONDS) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while ready.is_valid() and not bool(ready.call()):
		if Time.get_ticks_msec() > deadline:
			return false
		await _frames(1)
	if not ready.is_valid():
		_fail("WAIT LOST ITS SUBJECT")
		return false
	return true


## Waits until an opened envelope's papers are at rest.
func _settled(overlay: Object) -> void:
	if overlay == null:
		return
	if not await _until(func() -> bool: return not bool(overlay.call("is_busy"))):
		_fail("ENVELOPE NEVER SETTLED")


## The first Keep that can be pressed, or Take Nothing.
func _first_keep(papers: Array, overlay: Object) -> Button:
	for paper: Object in papers:
		var keep: Button = paper.get("keep")
		if not keep.disabled:
			return keep
	return overlay.call("nothing_button")


## Every ending and both deaths, once, in a sandbox put back after: a finished run with a
## full village is saved at the run's end and continued, so the ending screen opens the
## way a real run's end opens it. The Secret Contract's epilogue is photographed as it
## arrives; every page is then shown whole with an accept press, and Struggled once more
## at corruption stage 9. Last, Return to title is clicked, the save taken before is
## written back and the run resumed.
func _ending_frames() -> void:
	var controller: Object = _app.get("controller")
	var loop: RunLoop = controller.get("_loop")
	var snapshot: Dictionary = loop.record.to_dict()
	var saves: Object = root.get_node("Saves").call("run_service")
	for outcome: String in ENDING_RUNS:
		var screen: Node = await _open_ending(outcome, saves)
		if outcome == "secret_contract":
			await create_timer(0.5).timeout
			for frame: int in 3:
				await _snap("ending_secret_contract_epilogue_%d" % frame)
				await create_timer(1.1).timeout
		await _accept_epilogue(screen)
		var death: bool = outcome.begins_with("death_")
		await _shot(outcome if death else "ending_" + outcome)
	var was: int = ArtStages.stage_override
	ArtStages.stage_override = BOWL_STAGES[-1]
	var worn: Node = await _open_ending("struggled", saves)
	await _accept_epilogue(worn)
	await _shot("ending_struggled_stage_9")
	ArtStages.stage_override = was
	await _press(worn.call("home_button"))
	await _frames(20)
	var switcher: Object = _app.get("switcher")
	if switcher.call("current_id") != "title":
		_fail("ENDING DID NOT GO HOME")
	saves.call("save", snapshot)
	_app.call("resume_to_screen")
	await _frames(30)


## A full run once, in a sandbox put back after (ADR 0025): New Run without --demo starts
## the eight-Year run, whose first Set intro names the families at the table; the title
## then offers Continue for it, and Continue picks it up as a full run; the pause menu's
## Abandon asks first, with the focus on Keep playing, and clears the save. Then the
## demo's save is written back and the demo flow resumed.
func _full_run_frames() -> void:
	var saves: Object = root.get_node("Saves").call("run_service")
	var controller: Object = _app.get("controller")
	var loop: RunLoop = controller.get("_loop")
	var snapshot: Dictionary = loop.record.to_dict()
	_app.set("demo", false)
	var profile: SaveService = root.get_node("Saves").call("profile_service")
	var kept: Dictionary[String, String] = _keep_files(profile)
	await _meta_frames(profile)
	await _history_frames(profile)
	await _card_back_frames(profile)
	await _corruption_frames(profile)
	await _file_meta_frames(profile)
	Profile.write(profile, ProfileData.new())
	_app.call("show_screen", "title", true)
	await _frames(20)
	await _click_button_with_text(tr("title.new_run"))
	var shown: Object = _app.get("switcher")
	var setup: Node = shown.call("current")
	var promised: String = setup.call("player_name")
	await _click_button_with_text(tr("setup.start"))
	await _frames(20)
	_expect(bool(controller.call("has_village")), "FULL RUN NOT STARTED")
	var named: String = controller.call("player_name")
	_expect(named == promised, "RUN NAME %s IS NOT SETUP'S %s" % [named, promised])
	await _shot("full_run_set_intro")
	await _dossier_names()
	var menu: Node = _app.get("_menu")
	menu.call("open")
	await _frames(10)
	await _press(_button_in(menu, tr("pause.to_title")))
	await _frames(30)
	await _shot("title_full_run")
	var switcher: Object = _app.get("switcher")
	_expect(_button_in(switcher.call("current"), tr("title.continue")) != null, "NO CONTINUE")
	await _click_button_with_text(tr("title.continue"))
	await _frames(40)
	_expect(bool(controller.call("has_village")), "RESUME WRONG KIND")
	_expect(switcher.call("current_id") == "table", "RESUME WRONG SCREEN")
	await _abandon_frames(switcher.call("current"), saves)
	_put_back_files(kept)
	saves.call("save", snapshot)
	_app.set("demo", true)
	_app.call("resume_to_screen")
	await _frames(30)


## The dossier names each seated villager in full, given name first (ADR 0028).
func _dossier_names() -> void:
	_app.call("show_screen", "dossier")
	await _frames(20)
	await _shot("dossier_names")
	var shown: Object = _app.get("switcher")
	var page: Node = shown.call("current")
	for seat: int in [1, 2]:
		var controller: Object = _app.get("controller")
		var full: String = controller.call("seated_full_name", seat)
		var whole: bool = full.split(" ").size() == 2 and _shows_text(page, full)
		_expect(whole, "DOSSIER SEAT %d NAMED %s" % [seat, full])
	_app.call("back")
	await _frames(20)


## True when a label under node shows text.
func _shows_text(node: Node, text: String) -> bool:
	for found: Node in node.find_children("*", "Label", true, false):
		var shown: Label = found as Label
		if shown.is_visible_in_tree() and shown.text.contains(text):
			return true
	return false


## Run setup and the collection for a fresh profile and for one handed three finished
## runs, the third stake and an heirloom (ADR 0025): one household and one stake open,
## then all four households, three stakes and the inherited line; every item locked but
## tier 0's, then every item open. A click on The Old Family picks it.
func _meta_frames(profile: SaveService) -> void:
	Profile.write(profile, ProfileData.new())
	_app.call("show_screen", "title", true)
	await _frames(20)
	await _click_button_with_text(tr("title.collection"))
	await _shot("collection_locked")
	var switcher: Object = _app.get("switcher")
	var page: Node = switcher.call("current")
	var shown: String = page.call("open_line")
	_expect(shown == CollectionView.for_runs(0).open_line(), "COLLECTION COUNT WRONG")
	await _click_button_with_text(tr("coll.back"))
	await _click_button_with_text(tr("title.new_run"))
	await _shot("run_setup_full")
	var setup: Node = switcher.call("current")
	var player: String = setup.call("player_name")
	var full: bool = player.split(" ").size() == 2 and _shows_text(setup, player)
	_expect(full, "RUN SETUP SHOWS NO FULL NAME %s" % player)
	var open: int = 0
	for paper: Control in setup.call("papers"):
		open += 1 if bool(paper.get("choosable")) else 0
	_expect(open == 1, "FRESH SETUP OPENS %d HOUSEHOLDS" % open)
	await _click_button_with_text(tr("setup.back"))
	var veteran: ProfileData = ProfileData.new()
	veteran.finished_runs = 3
	veteran.generation = 3
	veteran.stake = 2
	veteran.lineage_kind = "heirloom"
	veteran.lineage_values = {"rank": Ranks.KING, "suit": 1}
	Profile.write(profile, veteran)
	await _click_button_with_text(tr("title.new_run"))
	setup = switcher.call("current")
	var papers: Array = setup.call("papers")
	var old_family: Control = papers[3]
	await _mouse_click(old_family.get_global_transform_with_canvas() * (old_family.size / 2.0))
	await _frames(10)
	_expect(setup.call("household") == "old_family", "HOUSEHOLD CLICK MISSED")
	await _shot("run_setup_veteran")
	_expect(int(setup.call("stake")) == 2, "VETERAN STAKE WRONG")
	await _click_button_with_text(tr("setup.back"))
	await _click_button_with_text(tr("title.collection"))
	await _shot("collection_open")
	await _wild_collection_frame()
	page = switcher.call("current")
	shown = page.call("open_line")
	_expect(shown == CollectionView.for_runs(3).open_line(), "OPEN COLLECTION COUNT WRONG")
	await _click_button_with_text(tr("coll.back"))


## The village history for a profile handed four finished runs, newest first: one with
## families dead, one a death, both classes.
func _history_frames(profile: SaveService) -> void:
	var data: ProfileData = ProfileData.new()
	var runs: Array[Array] = [
		[1, Endings.SECRET_CONTRACT, HistoryEntry.PEASANT, []],
		[2, Endings.LEAN_YEARS, HistoryEntry.PEASANT, [0, 3]],
		[3, Endings.DEATH_FAMINE, HistoryEntry.LANDLORD, []],
		[4, Endings.BENEVOLENT_LANDLORD, HistoryEntry.LANDLORD, [5]],
	]
	for values: Array in runs:
		var entry: HistoryEntry = HistoryEntry.new()
		entry.run_id = "playtest-%d" % values[0]
		entry.generation = values[0]
		entry.outcome = values[1]
		entry.class_id = values[2]
		entry.year = 3 if Endings.is_death(entry.outcome) else 8
		for family: int in values[3]:
			entry.dead.append(RunLoop.DEFAULT_VILLAGE.families[family].name_key)
		data.add_history(entry)
	data.finished_runs = runs.size()
	Profile.write(profile, data)
	_app.call("show_screen", "title", true)
	await _frames(20)
	await _click_button_with_text(tr("title.history"))
	var switcher: Object = _app.get("switcher")
	var page: Object = switcher.call("current")
	var records: Array = page.call("records")
	_expect(records.size() == runs.size(), "HISTORY HOLDS THE WRONG COUNT")
	await _shot("history_generations")
	await _click_button_with_text(tr("hist.back"))


## Settings with the card back row: the open design chosen, the others blank sheets.
func _card_back_frames(profile: SaveService) -> void:
	var data: ProfileData = ProfileData.new()
	data.finished_runs = 2
	Profile.write(profile, data)
	_app.call("show_screen", "title", true)
	await _frames(20)
	await _click_button_with_text(tr("title.settings"))
	var switcher: Object = _app.get("switcher")
	var page: Object = switcher.call("current")
	var row: Object = page.call("card_backs")
	var swatches: Array = [] if row == null else row.call("swatches")
	_expect(swatches.size() == 3, "NO CARD BACK ROW")
	await _shot("settings_card_backs")
	await _click_button_with_text(tr("settings.back"))


## The table at stages 0, 3, 6 and 9, each from a profile handed that corruption and read
## the way a run's start reads it, with no stage override.
func _corruption_frames(profile: SaveService) -> void:
	var saves: Object = root.get_node("Saves").call("run_service")
	for value: int in CORRUPTION_VALUES:
		var data: ProfileData = ProfileData.new()
		data.corruption = value
		Profile.write(profile, data)
		saves.call("delete")
		_app.call("show_screen", "title", true)
		await _frames(10)
		_expect(bool(_app.call("new_run", SEED + value)), "NO RUN AT CORRUPTION %d" % value)
		_app.call("show_screen", "table", true)
		await _frames(30)
		var stage: int = ArtStages.stage()
		var wanted: int = ArtStages.stage_of(value)
		_expect(stage == wanted, "STAGE %d AT CORRUPTION %d" % [stage, value])
		await _shot("table_corruption_%02d" % value)
	saves.call("delete")


## The profile's files as they are, to put back after the sandbox; a missing file is kept
## as missing.
func _keep_files(profile: SaveService) -> Dictionary[String, String]:
	var kept: Dictionary[String, String] = {}
	var path: String = profile.path()
	for file: String in [path, path + SaveService.BACKUP_SUFFIX]:
		kept[file] = FileAccess.get_file_as_string(file) if FileAccess.file_exists(file) else ""
	return kept


func _put_back_files(kept: Dictionary[String, String]) -> void:
	for file: String in kept:
		if kept[file].is_empty():
			DirAccess.remove_absolute(file)
			continue
		var out: FileAccess = FileAccess.open(file, FileAccess.WRITE)
		out.store_string(kept[file])
		out.close()


## The table's menu, Abandon run, and its question, then Abandon: the title, with no save.
func _abandon_frames(table: Node, saves: Object) -> void:
	var hud: Object = table.get("_hud")
	await _press(hud.get("menu"))
	await _frames(20)
	var pause: Node = table.get("_pause")
	await _press(_button_in(pause, tr("menu.abandon")))
	await _frames(20)
	await _shot("pause_abandon_confirm")
	var keep: Button = pause.call("keep_button")
	_expect(bool(pause.call("is_confirming")) and keep.has_focus(), "ABANDON FOCUS WRONG")
	await _press(pause.call("abandon_button"))
	await _frames(30)
	var switcher: Object = _app.get("switcher")
	_expect(switcher.call("current_id") == "title", "ABANDON DID NOT GO HOME")
	_expect(not FileAccess.file_exists(str(saves.call("path"))), "ABANDON KEPT THE SAVE")


## Counts a step that went wrong as a misclick, and says what it was.
func _expect(held: bool, failure: String) -> void:
	if not held:
		_fail(failure)


## Saves a run finished as outcome and continues it, which opens its ending.
func _open_ending(outcome: String, saves: Object) -> Node:
	var record: RunRecord = RunRecord.new()
	record.mark(_finished_run(ENDING_RUNS[outcome]))
	saves.call("save", record.to_dict())
	_app.call("resume_to_screen")
	await _frames(20)
	var switcher: Object = _app.get("switcher")
	if switcher.call("current_id") != "ending":
		_fail("NO ENDING SCREEN FOR %s" % outcome)
	return switcher.call("current")


## A run at its end with the given meters, Resentment and rounds as landlord, and every
## family of the village: some warm, some wary, some bitter, one in reeducation, one
## deposed and two dead.
func _finished_run(values: Array) -> RunState:
	var state: RunState = RunState.new(SEED)
	state.phase = RunFlow.State.RUN_END
	state.year = 8
	state.famine = values[0]
	state.denunciation = values[1]
	state.resentment = values[2]
	state.year_rounds = 4
	state.year_landlord_rounds = values[3]
	for family: FamilyDef in RunLoop.DEFAULT_VILLAGE.families:
		state.roster.append(RosterEntry.new(family.id))
	state.roster[1].status = RosterEntry.Status.REEDUCATION
	state.roster[4].status = RosterEntry.Status.DEPOSED
	state.roster[6].status = RosterEntry.Status.DEAD
	state.roster[11].status = RosterEntry.Status.DEAD
	var summary: SetSummary = SetSummary.new(0)
	for warm: int in [0, 5, 9]:
		summary.add(state.roster[warm].family_id, SetSummary.Kind.FED, 4)
	for bitter: int in [2, 8, 12]:
		summary.add(state.roster[bitter].family_id, SetSummary.Kind.DENOUNCED, 3)
	summary.add(state.roster[3].family_id, SetSummary.Kind.BOMBED, 1)
	state.memory.record(summary)
	return state


## Presses Enter, as any accept press shows the whole epilogue, and checks that it did.
## A page without an epilogue, or one already whole, is left alone: there Enter would
## press Return to title.
func _accept_epilogue(screen: Node) -> void:
	if screen.call("epilogue") == null or not bool(screen.call("is_revealing")):
		return
	for pressed: bool in [true, false]:
		var key: InputEventKey = InputEventKey.new()
		key.keycode = KEY_ENTER
		key.physical_keycode = KEY_ENTER
		key.pressed = pressed
		root.push_input(key, true)
		await _frames(2)
	var epilogue: Object = screen.call("epilogue")
	var lines: Array = epilogue.call("line_labels")
	if bool(screen.call("is_revealing")) or int(epilogue.call("shown_count")) != lines.size():
		_fail("EPILOGUE NOT SHOWN WHOLE")


## A picture of whatever node shows at corruption stage 9, the override put back after.
func _stage_9(shown: Object, name: String) -> void:
	var was: int = ArtStages.stage_override
	ArtStages.stage_override = BOWL_STAGES[-1]
	for node: Node in (shown as Node).find_children("*", "CanvasItem", true, false):
		(node as CanvasItem).queue_redraw()
	await _snap(name)
	ArtStages.stage_override = was
	for node: Node in (shown as Node).find_children("*", "CanvasItem", true, false):
		(node as CanvasItem).queue_redraw()


## Hands the player Mutual Aid at the run's first bid, in the state and in the Set's
## record, before anything could read it, so the pause before the first play comes the
## first time the player is a peasant, and still replays. The playtest never calls, so
## that is every round.
func _grant_opening() -> void:
	_opening_granted = true
	var controller: Object = _app.get("controller")
	var loop: RunLoop = controller.get("_loop")
	if loop.state.round_index != 0 or not loop.record.commands.is_empty():
		return
	loop.state.inventory.consumables.append("mutual_aid")
	var inventory: Dictionary = loop.record.checkpoint["inventory"]
	var held: Array = inventory["consumables"]
	held.append("mutual_aid")


## Coupons for a frame's purchase, in the state and in the record's checkpoint at the
## Set's end, so the purchase replays from the save.
func _grant_coupons(amount: int) -> void:
	var controller: Object = _app.get("controller")
	var loop: RunLoop = controller.get("_loop")
	loop.state.coupons += amount
	loop.record.checkpoint["coupons"] = int(loop.record.checkpoint["coupons"]) + amount
	# Handed over by this tool, so the second book is told (ADR 0022).
	controller.call("reseal_book")


## On the first turn after a Campaign was bought, in a sandbox put back after: the tray
## holding two leaflets, Model Harvest armed with cards chosen, its rosettes pressed on,
## Registration Drive's chops after it, a court card among the marked, and then the tray
## alone at corruption stage 9 (the table's own art keeps the stage it was drawn at, so
## the frame is named for the tray). The Campaigns are handed over through the run's
## state, which only this development tool does; then the save taken before is
## written back and resumed, so the run and its record go on as they were.
func _campaign_turn(table: Node, controller: Node) -> void:
	var loop: RunLoop = controller.get("_loop")
	var snapshot: Dictionary = loop.record.to_dict()
	loop.state.inventory.consumables.assign(["model_harvest", "registration_drive"])
	var campaigns: Object = table.get("_campaigns")
	campaigns.call("refresh")
	var tray: Object = campaigns.get("tray")
	await _shot("table_campaign_tray")
	var chosen: Array[int] = _marking_picks(2, [])
	await _arm_and_choose(table, tray, chosen)
	await _shot("table_campaign_armed")
	await _press(tray.get("use"))
	for frame: int in 4:
		await _snap("table_campaign_marking_%d" % frame)
	await create_timer(2.0).timeout
	await _arm_and_choose(table, tray, _marking_picks(3, chosen))
	await _press(tray.get("use"))
	await create_timer(2.0).timeout
	await _shot("table_campaign_marked")
	var was: int = ArtStages.stage_override
	ArtStages.stage_override = BOWL_STAGES[-1]
	loop.state.inventory.consumables.assign(["grain_loan", "anonymous_letter"])
	campaigns.call("refresh")
	for node: Node in table.find_children("*", "CanvasItem", true, false):
		(node as CanvasItem).queue_redraw()
	await _shot("table_campaign_tray_stage_9")
	ArtStages.stage_override = was
	var saves_hub: Object = root.get_node("Saves")
	var saves: Object = saves_hub.call("run_service")
	saves.call("save", snapshot)
	_app.call("resume_to_screen")
	await _frames(30)


## Arms the tray's first leaflet and clicks the cards for it.
func _arm_and_choose(table: Node, tray: Object, card_ids: Array[int]) -> void:
	await _mouse_click(tray.call("slot_center", 0))
	for card_id: int in card_ids:
		await _click_card(table, card_id)


## Up to count cards of the hand to mark, court cards first, none of them already taken.
func _marking_picks(count: int, taken: Array[int]) -> Array[int]:
	var hand: Object = _app.get("hand")
	var cards: Array = hand.call("cards")
	var picks: Array[int] = []
	var court: Array[int] = [Ranks.JACK, Ranks.QUEEN, Ranks.KING]
	for want_court: bool in [true, false]:
		for card: CardInstance in cards:
			if picks.size() >= count or taken.has(card.id()) or picks.has(card.id()):
				continue
			if court.has(card.base_rank()) == want_court:
				picks.append(card.id())
	return picks


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
		_fail("RESUME WRONG STATE %d" % controller.call("awaiting"))


## Photographs the audit dice as they tumble and once they have settled, when the bowl
## drops in after a claim; the claims on the slip come first, a step apart.
func _dice_frames(table: Node) -> void:
	var moments: Object = table.get("_moments")
	var bowl: Object = moments.get("dice")
	if not await _until(func() -> bool: return bool(bowl.call("is_rolling")), 4.0):
		return
	for frame: int in 3:
		await _snap("round%d_dice_roll_%d" % [_rounds_seen, frame])
	if not await _until(func() -> bool: return not bool(bowl.call("is_rolling"))):
		_fail("DICE NEVER SETTLED round %d" % _rounds_seen)
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
		_fail(
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


## Rests the pointer over a control, as a person reading it would.
func _hover(control: Control) -> void:
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.position = control.get_global_transform_with_canvas() * (control.size / 2.0)
	root.push_input(move, true)
	await _frames(6)


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
	if _headless:
		_named(name)
		return
	await RenderingServer.frame_post_draw
	_shots += 1
	var path: String = _out.path_join("%02d_%s.png" % [_shots, name])
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))


func _shot(name: String) -> void:
	# Count-ups and entrances run on the clock, and software rendering is slow, so wait
	# on time, not frames, before a picture.
	await create_timer(SETTLE_SECONDS).timeout
	if _headless:
		_named(name)
		return
	await RenderingServer.frame_post_draw
	_shots += 1
	var path: String = _out.path_join("%02d_%s.png" % [_shots, name])
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))


## A frame taken without a window: counted and named.
func _named(name: String) -> void:
	_shots += 1
	print("FRAME %02d_%s" % [_shots, name])
