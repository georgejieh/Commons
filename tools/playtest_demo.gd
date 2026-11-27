extends WalkBase
## The playtest's --demo walk: plays the demo through its real UI, the way a person would,
## for the rounds asked for, then every ending and a full run once (ADR 0025). It clicks
## the visible part of each card with mouse events, presses Play, Pass, Call and the
## store's buttons, takes a frame at each round's first turn and every few turns, and
## hands each screen's own frames to the walk of that screen: the table, the shops, the
## debuffs, the file, the wild ranks, the marks, the deal and the plot swap.
## Development only; tools/ never ships.

const Table := preload("res://tools/playtest_table.gd")
const Store := preload("res://tools/playtest_store.gd")
const Market := preload("res://tools/playtest_market.gd")
const Debuffs := preload("res://tools/playtest_debuffs.gd")
const RunEnd := preload("res://tools/playtest_run_end.gd")
const Marks := preload("res://tools/playtest_marks.gd")
const FileWalk := preload("res://tools/playtest_file.gd")
const Wild := preload("res://tools/playtest_wild.gd")
const Deal := preload("res://tools/playtest_deal.gd")
const Swap := preload("res://tools/playtest_swap.gd")
const SHOT_EVERY: int = 5
const STEP_FRAMES: int = 4
## Steps the walk may stand on one page other than the table before it is stuck.
const STUCK_STEPS: int = 40
## Steps the whole walk may take before it is failed as never ending.
const WALK_STEPS: int = 3000
## How far through its pressing the title's name is held for its picture.
const TITLE_PRESSED: float = 0.5
## What the controller awaits from the player: the bid, a swap, a play, the need's claim,
## the opening before the first play, and a villager's play being searched.
const AWAIT_BID: int = 1
const AWAIT_SWAP: int = 2
const AWAIT_PLAY: int = 3
const AWAIT_NEED: int = 4
const AWAIT_OPENING: int = 9
const AWAIT_SEARCH: int = 10

var _rounds_wanted: int
var _rounds_seen: int = 0
var _turns_in_round: int = 0
var _clicks: int = 0
## The page the walk stands on and for how many steps, for _stuck().
var _stood_on: String = ""
var _stood_steps: int = 0
var _driver: Object
var _toured: bool = false
var _resumed: bool = false
var _campaign_used: bool = false
var _opening_shot: bool = false
var _opening_granted: bool = false
var _debuffs_shot: bool = false
var _marks_table_shot: bool = false
## True from the state store's exchange until the table has shown the deck sheet.
var _deck_table_due: bool = false
var _deck_table_shown: bool = false
var _table: Table = Table.new()
var _store: Store = Store.new()
var _market: Market = Market.new()
var _debuffs: Debuffs = Debuffs.new()
var _run_end: RunEnd = RunEnd.new()
var _marks: Marks = Marks.new()
var _file: FileWalk = FileWalk.new()
var _wild: Wild = Wild.new()
var _deal: Deal = Deal.new()
var _swap: Swap = Swap.new()


## Starts the demo in the walk's own save folder and walks it; folder is that folder.
func run(folder: String, rounds: int) -> void:
	_rounds_wanted = rounds
	var saves: Node = tree.root.get_node("Saves")
	saves.call("use_run_path", folder + WalkProfile.RUN_FILE)
	# Loaded at run time: the demo names autoloads, which a --script tool can't see.
	app = (load("res://ui/main.tscn") as PackedScene).instantiate()
	app.set("demo", true)
	tree.root.add_child(app)
	var script: GDScript = load("res://tests/support/controller_script.gd")
	_driver = script.new()
	await _frames(20)
	await _first_launch()
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
			return
		await _step()
	await _run_end.endings()
	await _run_end.full_run(_file, _wild)
	# Headless, frames outrun the table's animations and the steps run out first: only a
	# walk on a display is failed for it.
	if guard >= WALK_STEPS and _rounds_seen <= _rounds_wanted and not headless:
		_fail("the walk ran out of steps after %d rounds" % _rounds_seen)
	print("rounds=%d clicks=%d misclicks=%d shots=%d" % [_rounds_seen, _clicks, misses, shots])


## The pages a first launch puts before the title: the content note, the family's name,
## whose default is taken (ADR 0028), and the arrival, which the demo skips (ADR 0026).
func _first_launch() -> void:
	if _screen_id() == "content_note":
		await _shot("content_note")
		await _click_button_with_text(tr("note.continue"))
		await _frames(20)
	if _screen_id() == "surname":
		await _press(_current().call("confirm_button"))
		await _frames(20)
	if _screen_id() == "arrival":
		await _click_button_with_text(tr("tutorial.skip"))
		var confirm: Object = _current().call("confirm")
		await _press(confirm.call("skip_button"))
		await _frames(20)


func _step() -> void:
	match _screen_id():
		"table":
			await _table_step()
		"set_summary":
			await _shot("set_summary")
			await _click_first_button()
		"store":
			await _store.visit(_marks, _file, _wild, _market)
			if _store.exchanged and not _deck_table_shown:
				_deck_table_due = true
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
	var table: Node = _current()
	if not _idle():
		return
	var actions: Object = table.get("actions")
	match int(_controller().call("awaiting")):
		AWAIT_BID:
			await _bid(table)
		AWAIT_NEED:
			var need_panel: Node = table.get("need_panel")
			await _press(member(need_panel, "more"))
			await _frames(6)
			await _shot("round%d_need" % _rounds_seen)
			await _press(need_panel.call("declare_button"))
			await _table.dice_frames(table, _rounds_seen)
			await _shot("round%d_audit" % _rounds_seen)
		AWAIT_SWAP:
			await _swap.answer(table, _rounds_seen)
		AWAIT_PLAY:
			await _play_turn(table)
		AWAIT_OPENING:
			# The opening before the first play, when a held Campaign could be used.
			if not _opening_shot:
				_opening_shot = true
				await _shot("round%d_opening" % _rounds_seen)
			await _press(actions.get("play_on"))
		AWAIT_SEARCH:
			# A villager's play is being searched: nothing to press, so the walk waits.
			pass


## A round's bid: the first round's grants, the leave-and-continue on the third, the
## sandboxes on the second, and a decline every other time.
func _bid(table: Node) -> void:
	_rounds_seen += 1
	_turns_in_round = 0
	if not _opening_granted:
		_grant_opening()
	await _shot("round%d_bid" % _rounds_seen)
	if _rounds_seen == 3 and not _resumed:
		_resumed = true
		await _table.leave_and_continue(table)
		return
	if _rounds_seen == 2 and not _debuffs_shot:
		_debuffs_shot = true
		await _debuffs.beats(_driver)
		await _debuffs.rules()
		await _wild.table(_driver)
		await _file.table()
		await _deal.table()
		return
	var actions: Object = table.get("actions")
	await _press(actions.get("decline"))
	if _rounds_seen <= 2:
		await _frames(5)
		await _shot("round%d_bid_stamps" % _rounds_seen)


func _play_turn(table: Node) -> void:
	_turns_in_round += 1
	if _turns_in_round == 1 or _turns_in_round % SHOT_EVERY == 0:
		await _shot("round%d_turn%d" % [_rounds_seen, _turns_in_round])
	var where: String = "round %d turn %d" % [_rounds_seen, _turns_in_round]
	_table.check_fan(table, where)
	if _rounds_seen >= 2 and not _marks_table_shot:
		_marks_table_shot = true
		await _marks.table()
	if _deck_table_due:
		_deck_table_due = false
		_deck_table_shown = true
		await _marks.table_deck()
	if not _toured:
		_toured = true
		await _table.tour(table)
	if not _table.hint_shot:
		await _table.hint_cards_frame(table, where)
	if _store.campaign_bought and not _campaign_used:
		_campaign_used = true
		await _table.campaign_turn(table)
		return
	var controller: Object = _controller()
	var ids: Array[int] = _driver.call("choose_play", controller)
	var actions: Object = table.get("actions")
	if ids.is_empty():
		await _press(actions.get("pass_turn"))
		return
	var hand: Object = app.get("hand")
	for card_id: int in ids:
		await _click_card(table, card_id)
		_clicks += 1
		if not hand.call("is_selected", card_id):
			_misclick("%s card %d" % [where, card_id])
	await _frames(2)
	var play: Button = actions.get("play")
	if play.disabled:
		var reading: Label = actions.get("reading")
		print("PLAY DISABLED %s: %s" % [where, reading.text])
		for card_id: int in ids:
			hand.call("set_selected", card_id, true)
	await _press(play)


## True when the walk has stood on one page, not the table, for more steps than any page
## takes: a button it cannot reach, such as one off the screen. Says so as a misclick, so
## the walk fails at once and never runs out its time.
func _stuck() -> bool:
	var screen_id: String = _screen_id()
	if screen_id != _stood_on or screen_id == "table":
		_stood_on = screen_id
		_stood_steps = 0
		return false
	_stood_steps += 1
	if _stood_steps <= STUCK_STEPS:
		return false
	_misclick("stuck on %s after %d steps" % [screen_id, _stood_steps])
	return true


## Hands the player Mutual Aid at the run's first bid, in the state and in the Set's
## record, before anything could read it, so the pause before the first play comes the
## first time the player is a peasant, and still replays. The walk always declines the
## bid, so the player is a peasant every round.
func _grant_opening() -> void:
	_opening_granted = true
	var loop: RunLoop = _loop()
	if loop.state.round_index != 0 or not loop.record.commands.is_empty():
		return
	loop.state.inventory.consumables.append("mutual_aid")
	var inventory: Dictionary = loop.record.checkpoint["inventory"]
	var held: Array = inventory["consumables"]
	held.append("mutual_aid")
	# The plot too, so every round of the walk offers the swap.
	_swap.grant(loop)


## The collection from the title: both grids, then scrolled to its last card by focus,
## as a gamepad would.
func _collection_frames() -> void:
	await _click_button_with_text(tr("title.collection"))
	await _frames(30)
	await _shot("collection")
	var entries: Array = _current().call("entries")
	if not entries.is_empty():
		var last: Control = entries[-1]
		last.grab_focus()
		await _frames(10)
		await _shot("collection_scrolled")
	await _click_button_with_text(tr("coll.back"))
	await _frames(20)
	await _title_pressing_frame()


## The title's name part way through its pressing, held there for the picture: a slow
## renderer has the real pressing over before it draws a frame of it. Not under reduced
## motion, where the name is never pressed.
func _title_pressing_frame() -> void:
	var screen: Node = _current()
	if options.has(DisplayFlags.REDUCED_MOTION) or not screen.has_method("word"):
		return
	var word: Object = screen.call("word")
	await tree.create_timer(SETTLE_SECONDS).timeout
	var whole: float = word.call("seconds")
	word.set("clock", whole * TITLE_PRESSED)
	await _snap("title_pressing")
	word.set("clock", whole)


## The Set intro with a Slogan of the Week on its ladder, naming Pairs, put there through
## the run's state for the picture and taken off again before the Set begins.
func _slogan_frame() -> void:
	var loop: RunLoop = _loop()
	var ladder: Array[String] = loop.state.debuff_ladder.duplicate()
	var slogan: int = loop.state.slogan_type
	loop.state.debuff_ladder[1] = "slogan_of_the_week"
	loop.state.slogan_type = Pattern.Type.PAIR
	app.call("show_screen", "set_intro", true)
	await _shot("set_intro_slogan")
	loop.state.debuff_ladder = ladder
	loop.state.slogan_type = slogan
	app.call("show_screen", "set_intro", true)
	await _frames(20)
