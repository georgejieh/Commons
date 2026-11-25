extends GdUnitTestSuite
## The Campaigns that give the new marks (ADR 0041): Autumn Gleaning, Emulation Contest and
## Surplus Sale each mark one or two cards in hand for the run with their enhancement, in
## place of any other, through the same effect as Model Harvest. Each is in the state
## store's pool and open from the first run, and a card already carrying its mark is
## refused.

const SEEDS: int = 80
const GIVES: Dictionary[String, String] = {
	"autumn_gleaning": CardInstance.SHEAF,
	"emulation_contest": CardInstance.PENNANT,
	"surplus_sale": CardInstance.SURPLUS,
}


func _find(held: Array[String]) -> RunLoop:
	for seed_value: int in range(1, 1 + SEEDS):
		var state: RunState = RunState.new(seed_value)
		state.inventory.consumables.assign(held)
		var loop: RunLoop = RunLoop.new(state, RunScript.bots(), SetConfig.new())
		loop.start_set()
		var script: RunScript = RunScript.new()
		for _step: int in 300:
			if loop.awaiting() == RunLoop.Awaiting.PLAYER_PLAY:
				return loop
			if not script.act(loop):
				break
	return null


func test_each_is_in_the_state_stores_pool_and_open_from_the_first_run() -> void:
	var open: Array[CampaignDef] = RunUnlocks.campaigns(RunPools.STORE_CAMPAIGNS.campaigns, 0)
	var ids: Array[String] = []
	for definition: CampaignDef in open:
		ids.append(definition.id)
	for campaign_id: String in GIVES:
		assert_array(ids).contains([campaign_id])
		assert_bool(CampaignRegistry.has_effect(campaign_id)).is_true()


func test_each_marks_the_chosen_cards_for_the_run_in_place_of_another_mark() -> void:
	for campaign_id: String in GIVES:
		var mark: String = GIVES[campaign_id]
		var loop: RunLoop = _find([campaign_id])
		assert_object(loop).override_failure_message(campaign_id).is_not_null()
		var hand: Array[CardInstance] = loop.player_cards()
		var chosen: Array[int] = [hand[0].id(), hand[1].id()]
		# The first card is a Model card already: the new mark takes its place.
		var to_model: Callable = func(card: CardInstance) -> void:
			CardMarks.enhance(loop.state, card, CardInstance.MODEL)
		loop.round_state().mark(RunLoop.PLAYER, chosen[0], to_model)
		assert_int(loop.player_campaign(0, chosen)).is_equal(RunLoop.Reason.OK)
		for card: CardInstance in loop.player_cards():
			if chosen.has(card.id()):
				assert_str(card.enhancement_id()).is_equal(mark)
		for card_id: int in chosen:
			if card_id < Deck.SIZE:
				assert_str(loop.state.card_marks.enhancements[card_id]).is_equal(mark)
		var marked: Array[RunEvent] = loop.events().filter(
			func(event: RunEvent) -> bool: return event.type == RunEvent.Type.CARDS_MARKED
		)
		assert_int(marked[-1].value).is_equal(CardInstance.mark_value(mark))
		assert_str(CardInstance.marked_by(marked[-1].value)).is_equal(mark)


func test_a_card_already_so_marked_is_refused() -> void:
	var loop: RunLoop = _find(["autumn_gleaning"])
	var card_id: int = loop.player_cards()[0].id()
	var to_sheaf: Callable = func(card: CardInstance) -> void:
		CardMarks.enhance(loop.state, card, CardInstance.SHEAF)
	loop.round_state().mark(RunLoop.PLAYER, card_id, to_sheaf)
	var chosen: Array[int] = [card_id]
	assert_int(loop.campaign_reason(0, chosen)).is_equal(CampaignEffect.Reason.ALREADY_MARKED)
	assert_int(loop.player_campaign(0, chosen)).is_not_equal(RunLoop.Reason.OK)
