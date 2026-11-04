class_name ControllerScript
extends RefCounted
## Drives the player's seat through RunController alone, as a UI would: bids and plays
## by a fixed bot and declares a fixed need.

const NEED: int = 12

var config: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.MEDIUM)


## Takes one player turn. Returns false when the run is not waiting on the player.
func act(controller: RunController) -> bool:
	match controller.awaiting():
		RunLoop.Awaiting.PLAYER_BID:
			var claim: bool = Bot.decide_bid(
				counts(controller.player_cards()),
				false,
				false,
				controller.player_table(),
				config,
				BotBudget.unlimited()
			)
			return controller.bid(claim) == RunLoop.Reason.OK
		RunLoop.Awaiting.PLAYER_PLAY:
			return _play(controller)
		RunLoop.Awaiting.PLAYER_NEED:
			return controller.declare_need(NEED) == RunLoop.Reason.OK
	return false


## Plays Sets until the run is over.
func play_run(controller: RunController) -> void:
	while true:
		while act(controller):
			pass
		if controller.awaiting() != RunLoop.Awaiting.SET_OVER:
			return
		controller.finish_set()


func _play(controller: RunController) -> bool:
	var view: SeatView = controller.seat_view()
	var play: BotPlay = Bot.decide_play(
		view, controller.legal_moves(), controller.player_table(), config, BotBudget.unlimited()
	)
	if play.is_pass():
		return controller.pass_turn() == RunLoop.Reason.OK
	return controller.play(controller.card_ids_for(play.pattern)) == RunLoop.Reason.OK


static func counts(cards: Array[CardInstance]) -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	result.resize(Ranks.COUNT)
	for card: CardInstance in cards:
		result[card.base_rank()] += 1
	return result
