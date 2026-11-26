class_name RunScript
extends RefCounted
## Drives the player's seat for tests: bids and plays by a fixed bot, declares a fixed
## need, and swaps the plot's first card for the hand's lowest when it can.

const NEED: int = 12
## The most turns play_to takes before it fails: far more than a whole Set needs.
const MOST_TURNS: int = 5000

var config: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.MEDIUM)
## Player commands in order, as text, for logs and replays.
var commands: PackedStringArray = []


static func bots() -> Array[BotConfig]:
	return [
		BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.MEDIUM),
		BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.MEDIUM),
		BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.HARD),
	]


## Leaves a finished Set as the player does: through the shops, or reeducation when it
## is due, then on; the run's last Set straight to its end. Elsewhere it is next_set().
static func next_set(loop: RunLoop) -> RunLoop.Reason:
	if loop.awaiting() == RunLoop.Awaiting.SET_OVER and not loop.is_last_set():
		loop.open_shop()
	return loop.next_set()


## A new run's first Set played through and its shops opened. The coupons are handed over
## at the Set's end, where the record's checkpoint is, so a replay has them too.
static func at_the_shops(
	suite: GdUnitTestSuite, seed_value: int, coupons: int, reforms: Array[String] = []
) -> RunLoop:
	var state: RunState = RunState.new(seed_value)
	state.reforms.assign(reforms)
	var loop: RunLoop = RunLoop.new(state, bots(), SetConfig.new())
	loop.start_set()
	RunScript.new().play_to(suite, loop, RunLoop.Awaiting.SET_OVER)
	loop.state.coupons = coupons
	loop.record.mark(loop.state)
	suite.assert_int(loop.open_shop()).is_equal(RunLoop.Reason.OK)
	return loop


## Takes the player's turns until the loop awaits moment, and says whether it got there.
## It fails suite, naming both moments, when the loop stops waiting on the player first or
## after MOST_TURNS turns.
func play_to(suite: GdUnitTestSuite, loop: RunLoop, moment: RunLoop.Awaiting) -> bool:
	for _turn: int in MOST_TURNS:
		if loop.awaiting() == moment or not act(loop):
			break
	if loop.awaiting() == moment:
		return true
	var names: Array = RunLoop.Awaiting.keys()
	suite.fail("The loop awaits %s, not %s" % [names[loop.awaiting()], names[moment]])
	return false


## Acts until the loop waits on something other than the player.
func play_until_set_over(loop: RunLoop) -> void:
	while act(loop):
		pass


## Takes one player turn. Returns false when the loop is not waiting on the player.
func act(loop: RunLoop) -> bool:
	match loop.awaiting():
		RunLoop.Awaiting.PLAYER_BID:
			var claim: bool = Bot.decide_bid(
				ControllerScript.counts(loop.player_cards()),
				false,
				false,
				loop.seat_table(RunLoop.PLAYER),
				config,
				BotBudget.unlimited()
			)
			commands.append("bid %s" % claim)
			return loop.player_bid(claim) == RunLoop.Reason.OK
		RunLoop.Awaiting.PLAYER_SWAP:
			return _swap(loop)
		RunLoop.Awaiting.PLAYER_PLAY:
			return _play(loop)
		RunLoop.Awaiting.PLAYER_NEED:
			commands.append("need %d" % NEED)
			return loop.player_need(NEED) == RunLoop.Reason.OK
		RunLoop.Awaiting.PLAYER_OPENING:
			commands.append("begin")
			return loop.player_begin() == RunLoop.Reason.OK
	return false


func _play(loop: RunLoop) -> bool:
	var round_state: RoundState = loop.round_state()
	var play: BotPlay = Bot.decide_play(
		round_state.view_for(RunLoop.PLAYER),
		round_state.legal_moves(),
		loop.seat_table(RunLoop.PLAYER),
		config,
		BotBudget.unlimited()
	)
	var ids: Array[int] = []
	if not play.is_pass():
		ids = round_state.action_for(play.pattern).card_ids
	elif round_state.pass_reason() == RoundState.Reason.MUST_PLAY:
		# Night Shift refuses the pass: the lowest legal play goes instead (ADR 0023).
		ids = round_state.action_for(round_state.legal_moves()[0]).card_ids
	commands.append("play %s" % str(ids))
	return loop.player_play(ids) == RunLoop.Reason.OK


func _swap(loop: RunLoop) -> bool:
	var lowest: CardInstance = null
	for card: CardInstance in loop.player_cards():
		if lowest == null or card.base_rank() < lowest.base_rank():
			lowest = card
	var hand_ids: Array[int] = [lowest.id()]
	var plot_ids: Array[int] = [loop.state.inventory.plot[0].id()]
	commands.append("swap %s %s" % [str(hand_ids), str(plot_ids)])
	return loop.player_swap(hand_ids, plot_ids) == RunLoop.Reason.OK
