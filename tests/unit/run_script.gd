class_name RunScript
extends RefCounted
## Drives the player's seat for tests: bids and plays by a fixed bot, declares a fixed
## need, and swaps the plot's first card for the hand's lowest when it can.

const NEED: int = 12

var config: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.MEDIUM)
## Player commands in order, as text, for logs and replays.
var commands: PackedStringArray = []


static func bots() -> Array[BotConfig]:
	return [
		BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.MEDIUM),
		BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.MEDIUM),
		BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.HARD),
	]


## Acts until the loop waits on something other than the player.
func play_until_set_over(loop: RunLoop) -> void:
	while act(loop):
		pass


## Takes one player turn. Returns false when the loop is not waiting on the player.
func act(loop: RunLoop) -> bool:
	match loop.awaiting():
		RunLoop.Awaiting.PLAYER_BID:
			var claim: bool = Bot.decide_bid(
				loop.player_counts(),
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
