extends WalkBase
## The playtest's frames of the debuffs at the table (ADR 0023), each in a sandbox put back
## after: every table beat, then the rules slip under the right seat.
## Development only; tools/ never ships.

## How many rounds the Night Shift sandbox's Quota may run, so its refusal comes.
const NIGHT_SHIFT_ROUNDS: int = 12
## What awaiting() says while the bid is the player's.
const AWAIT_BID: int = 1
const BEATS: Array[String] = [
	"levy", "redistribution", "confiscation", "glass_walls", "plot_seized", "night_shift"
]


## Each table beat of the debuffs, at a round's bid: the debuff is put in force for the rest
## of the Quota through the run's state, with the Cadres or plot cards it needs, in a Quota
## no one can meet so the sandbox plays on as long as a beat needs; the bid is declined so
## the round starts after the kitty and the beat plays; then the save taken before is
## written back and resumed. driver plays the player's turns where a beat needs them.
func beats(driver: Object) -> void:
	for debuff_id: String in BEATS:
		var loop: RunLoop = _loop()
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
		assign(loop, "_sets", SetConfig.new(params))
		_force_debuff(loop, debuff_id)
		await _beat(debuff_id, driver)
		await _restore(snapshot)


## The rules slip under the right seat (ADR 0034, rules 6 and 7), staged in a sandbox put
## back after: one short debuff in force, which it shows in full, then the three that
## stand tallest, which it names at most sizes, each with a play on the trick.
func rules() -> void:
	var cases: Dictionary[String, Array] = {
		"table_rules_one": ["", "straightened_lines", "", ""],
		"table_rules_worst": ["", "plot_seized", "night_shift", "criticism_meeting"],
	}
	for frame: String in cases:
		var loop: RunLoop = _loop()
		var snapshot: Dictionary = loop.record.to_dict()
		var ladder: Array[String] = []
		ladder.assign(cases[frame])
		loop.state.debuff_ladder.assign(ladder)
		loop.state.round_index = ladder.size() - 1
		var table: Node = app.call("show_screen", "table", true)
		await _frames(30)
		var held: Array = view(_controller(), "table").call("player_cards")
		var play: Array[CardInstance] = []
		for card: CardInstance in held.slice(0, 3):
			play.append(card)
		var pile: Node = member(table, "pile")
		pile.call("show_play", play, Vector2(790, 200))
		await _shot(frame)
		await _restore(snapshot)


## Puts a debuff in force from the round under way to the Quota's end, as if it had
## arrived with this round. A Set's first round is always clean, so there the stack takes
## it straight and the ladder's next step carries it on.
func _force_debuff(loop: RunLoop, debuff_id: String) -> void:
	var round_index: int = loop.state.round_index
	loop.state.debuff_ladder[maxi(round_index, 1)] = debuff_id
	invoke(loop, "rebuild_modifiers")
	if round_index >= 1:
		return
	var stack: ModifierStack = member(loop, "_stack")
	for definition: ModifierDef in RunPools.DEBUFFS.debuffs:
		if definition.id == debuff_id:
			loop.campaigns.flags.round_debuff = stack.add(definition, RunLoop.PLAYER)
	loop.debuffs.rebuilt()


func _beat(debuff_id: String, driver: Object) -> void:
	var controller: Object = _controller()
	if debuff_id == "confiscation":
		await _until(_struck_on_board)
		if not _struck_on_board():
			_fail("NO CONFISCATION MARK")
		await _snap("table_confiscation_0")
		await _shot("table_confiscation")
		return
	var before: Array[int] = _beats_now()
	await _decline_bids(controller, debuff_id)
	# Under reduced motion passed cards are not slid across the table: the hand shows as
	# it ends up, which is the frame (ADR 0035's walk).
	var still: bool = bool(DisplayFlags.settings(tree.root).value(DisplayFlags.REDUCED_MOTION_KEY))
	match debuff_id:
		"levy", "redistribution" when still:
			await _until(_idle)
			await _shot("table_%s" % debuff_id)
		"levy", "redistribution", "plot_seized":
			if not await _until(_beat_counted.bind(before)):
				_fail("NO BEAT %s" % debuff_id)
				return
			for frame: int in 3:
				await _snap("table_%s_%d" % [debuff_id, frame])
		"glass_walls":
			await _until(_idle)
			await _shot("table_glass_walls")
		"night_shift":
			await _night_shift_frame(controller, driver)


## Declines every bid put to the player until the round is in play, each once the bid
## bar shows, waiting on conditions in real seconds.
func _decline_bids(controller: Object, debuff_id: String) -> void:
	var deadline: int = Time.get_ticks_msec() + int(WAIT_SECONDS * 1000.0)
	while int(controller.call("awaiting")) == AWAIT_BID and Time.get_ticks_msec() < deadline:
		await _until(_decline_ready.bind(controller))
		var actions: Object = _part("actions")
		if actions != null and int(controller.call("awaiting")) == AWAIT_BID:
			await _press(actions.get("decline"))
		await _frames(2)
	if int(controller.call("awaiting")) == AWAIT_BID:
		_misclick("bid not declined %s" % debuff_id)


## True once the bid is no longer the player's, or its bar shows with the table at rest.
func _decline_ready(controller: Object) -> bool:
	if int(controller.call("awaiting")) != AWAIT_BID:
		return true
	var actions: Object = _part("actions")
	if actions == null or not _idle():
		return false
	var decline: Button = actions.get("decline")
	return decline != null and decline.is_visible_in_tree()


## The table on screen and how many debuff beats it has acted out: [its ID, the count],
## or [0, 0] off the table.
func _beats_now() -> Array[int]:
	var beats_part: Object = _part("debuff_beats")
	if beats_part == null:
		return [0, 0]
	return [_current().get_instance_id(), int(beats_part.get("beats_played"))]


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
func _night_shift_frame(controller: Object, driver: Object) -> void:
	for _turn: int in 400:
		await _until(_idle)
		if not str(view(controller, "table").call("pass_refusal")).is_empty():
			var actions: Object = _part("actions")
			if actions != null:
				await _press(actions.get("pass_turn"))
				await _shot("table_night_shift")
				return
		if not bool(driver.call("act", controller)):
			await _frames(5)
	_fail("NO NIGHT SHIFT REFUSAL")


## True while a Cadre on the notice board is struck out for the round.
func _struck_on_board() -> bool:
	var board: Object = _part("board")
	if board == null:
		return false
	for index: int in int(board.call("slot_count")):
		if bool(board.call("is_struck", index)):
			return true
	return false
