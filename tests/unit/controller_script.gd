class_name ControllerScript
extends RefCounted
## Drives the player's seat through RunController alone, as a UI would: bids and plays
## by a fixed bot and declares a fixed need.

const NEED: int = 12

var config: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.MEDIUM)


## Takes one player turn. Returns false when the run is not waiting on the player.
func act(controller: RunController) -> bool:
	match controller.awaiting():
		RunController.AWAIT_BID:
			var claim: bool = Bot.decide_bid(
				counts(controller.player_cards()),
				false,
				false,
				controller.player_table(),
				config,
				BotBudget.unlimited()
			)
			return controller.bid(claim) == RunController.OK
		RunController.AWAIT_PLAY:
			return _play(controller)
		RunController.AWAIT_NEED:
			return controller.declare_need(NEED) == RunController.OK
	return false


## Plays Sets until the run is over, buying the first Cadre it can afford at each store.
func play_run(controller: RunController) -> void:
	while true:
		while act(controller):
			pass
		match controller.awaiting():
			RunController.AWAIT_SET_OVER:
				controller.finish_set()
			RunController.AWAIT_STORE:
				for slot: int in controller.store_stock().size():
					if controller.can_buy(slot):
						controller.buy(slot)
						break
				controller.leave_store()
			_:
				return


func _play(controller: RunController) -> bool:
	var view: SeatView = controller.seat_view()
	var play: BotPlay = Bot.decide_play(
		view, controller.legal_moves(), controller.player_table(), config, BotBudget.unlimited()
	)
	if play.is_pass():
		return controller.pass_turn() == RunController.OK
	return controller.play(controller.card_ids_for(play.pattern)) == RunController.OK


static func counts(cards: Array[CardInstance]) -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	result.resize(Ranks.COUNT)
	for card: CardInstance in cards:
		result[card.base_rank()] += 1
	return result
