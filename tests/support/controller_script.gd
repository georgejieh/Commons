class_name ControllerScript
extends RefCounted
## Drives the player's seat through RunController alone, as a UI would: bids and plays
## by a fixed bot and declares a fixed need.

const NEED: int = 12
## The most commands play_to gives before it fails: far more than a whole Set needs.
const MOST_TURNS: int = 5000

var config: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.MEDIUM)


## Takes one player turn. Returns false when the run is not waiting on the player. A
## villager whose play is searched is waited for, as a UI would, then it goes on.
func act(controller: RunController) -> bool:
	match controller.awaiting():
		RunController.AWAIT_VILLAGER:
			controller.settle_search()
			return true
		RunController.AWAIT_BID:
			var claim: bool = Bot.decide_bid(
				counts(controller.table.player_cards()),
				false,
				false,
				controller.table.player_table(),
				config,
				BotBudget.unlimited()
			)
			return controller.bid(claim) == RunController.OK
		RunController.AWAIT_PLAY:
			return _play(controller)
		RunController.AWAIT_NEED:
			return controller.declare_need(NEED) == RunController.OK
		RunController.AWAIT_OPENING:
			return controller.begin_round() == RunController.OK
	return false


## Takes the player's turns until the run awaits moment, and says whether it got there. It
## fails suite, naming both moments, when the run stops waiting on the player first or
## after MOST_TURNS commands.
func play_to(suite: GdUnitTestSuite, controller: RunController, moment: int) -> bool:
	for _turn: int in MOST_TURNS:
		if controller.awaiting() == moment or not act(controller):
			break
	if controller.awaiting() == moment:
		return true
	suite.fail("The run awaits %d, not %d" % [controller.awaiting(), moment])
	return false


## Plays Sets until the run is over, buying the first Cadre it can afford at each store,
## and going back from reeducation when it is owed.
func play_run(controller: RunController) -> void:
	while true:
		while act(controller):
			pass
		match controller.awaiting():
			RunController.AWAIT_SET_OVER:
				controller.finish_set()
			RunController.AWAIT_STORE:
				for slot: int in controller.store.store_stock().size():
					if controller.store.can_buy(slot):
						controller.buy(slot)
						break
				controller.leave_store()
			RunController.AWAIT_REEDUCATION:
				controller.leave_reeducation()
			_:
				return


## The card IDs the script would play now; empty is a pass.
func choose_play(controller: RunController) -> Array[int]:
	var view: SeatView = controller.table.seat_view()
	var play: BotPlay = Bot.decide_play(
		view,
		controller.table.legal_moves(),
		controller.table.player_table(),
		config,
		BotBudget.unlimited()
	)
	if play.is_pass() and not controller.table.pass_refusal().is_empty():
		# Night Shift refuses the pass: the first legal play goes instead (ADR 0023).
		return controller.table.card_ids_for(controller.table.legal_moves()[0])
	if play.is_pass():
		return []
	return controller.table.card_ids_for(play.pattern)


func _play(controller: RunController) -> bool:
	var ids: Array[int] = choose_play(controller)
	if ids.is_empty():
		return controller.pass_turn() == RunController.OK
	return controller.play(ids) == RunController.OK


static func counts(cards: Array[CardInstance]) -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	result.resize(Ranks.COUNT)
	for card: CardInstance in cards:
		result[card.base_rank()] += 1
	return result
