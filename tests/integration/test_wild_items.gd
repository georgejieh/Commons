extends GdUnitTestSuite
## ADR 0029's three items played through the run loop. Model Worker makes one rank wild for
## the player's seat alone (ADR 0039) for the round it is used in, a second beside one
## already wild, never a third, and only before the first play. Mass Line draws a rank
## with every deal, after it, so the deal is the same with or without it, and the rank is
## named before the bid, for the player's seat alone. Each
## draw replays from a save. Industrialization is test_wild_bombs.gd.
## The golden numbers are this seed's draws and scores; they change only with the rules.

const SEED: int = 7301
const SEEDS: int = 60
## Model Worker's two draws on SEED's first opening, and Mass Line's first three rounds.
const GOLDEN_WORKER: Array[int] = [Ranks.JACK, Ranks.NINE]
const GOLDEN_MASS_LINE: Array[int] = [Ranks.JACK, Ranks.KING, Ranks.TEN]

static var _dir: String = TestFolder.of("test_wild_items")

var _service: SaveService


func before_test() -> void:
	_service = SaveService.for_run(_dir + "run.json")
	_service.delete()


func after_test() -> void:
	_service.delete()


func _loop(seed_value: int, held: Array[String], reforms: Array[String] = []) -> RunLoop:
	var state: RunState = RunState.new(seed_value)
	state.inventory.consumables.assign(held)
	state.reforms.assign(reforms)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots(), SetConfig.new())
	loop.start_set()
	return loop


## Plays the player's seat until moment says the loop stands where a test wants it.
func _drive(loop: RunLoop, moment: Callable, script: RunScript = RunScript.new()) -> bool:
	for _step: int in 400:
		if moment.call(loop):
			return true
		if not script.act(loop):
			return false
	return false


## Before the first play, where Model Worker may be used: a peasant's opening or the
## landlord player's first turn.
func _before_first_play(loop: RunLoop) -> bool:
	var awaiting: RunLoop.Awaiting = loop.awaiting()
	if awaiting == RunLoop.Awaiting.PLAYER_OPENING:
		return true
	return (
		awaiting == RunLoop.Awaiting.PLAYER_PLAY
		and loop.round_state().public_view().history.is_empty()
	)


func _after_first_play(loop: RunLoop) -> bool:
	return (
		loop.awaiting() == RunLoop.Awaiting.PLAYER_PLAY
		and not loop.round_state().public_view().history.is_empty()
	)


func _events_of(loop: RunLoop, type: RunEvent.Type) -> Array[RunEvent]:
	return loop.events().filter(func(event: RunEvent) -> bool: return event.type == type)


func _log_lines(loop: RunLoop) -> Array:
	var lines: Array = []
	for event: RunEvent in loop.events():
		lines.append(event.describe())
	return lines


func _through_json(loop: RunLoop) -> Dictionary:
	_service.save(loop.record.to_dict())
	var loaded: SaveLoad = _service.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.OK)
	return loaded.data


## The player's seat holds the ranks wild; a villager's cards of them are plain cards.
func _only_the_player_has_wild(loop: RunLoop, ranks: Array[int]) -> void:
	for seat: int in Seats.COUNT:
		var rules: RuleSet = loop.seat_table(seat).rules
		if seat == RunLoop.PLAYER:
			assert_array(rules.wild_ranks()).contains_exactly_in_any_order(ranks)
		else:
			assert_array(rules.wild_ranks()).is_empty()


func test_model_worker_makes_one_rank_wild_then_a_second_then_refuses() -> void:
	var held: Array[String] = ["model_worker", "model_worker", "model_worker"]
	var loop: RunLoop = _loop(SEED, held)
	assert_bool(_drive(loop, _before_first_play)).is_true()
	assert_array(loop.state.wild_ranks).is_empty()
	var none: Array[int] = []
	assert_int(loop.player_campaign(0, none)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.wild_ranks.size()).is_equal(1)
	var first: int = loop.state.wild_ranks[0]
	assert_bool(first >= Ranks.THREE and first <= Ranks.TWO).is_true()
	_only_the_player_has_wild(loop, [first])
	var named: Array[RunEvent] = _events_of(loop, RunEvent.Type.WILD_RANKS)
	assert_int(named.size()).is_equal(1)
	assert_int(named[0].value).is_equal(first)
	assert_str(named[0].text).is_equal(str(first))
	# The second makes another rank wild, never the same one.
	assert_int(loop.player_campaign(0, none)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.wild_ranks.size()).is_equal(2)
	var second: int = loop.state.wild_ranks[1]
	assert_int(second).is_not_equal(first)
	_only_the_player_has_wild(loop, [first, second])
	assert_str(_events_of(loop, RunEvent.Type.WILD_RANKS)[1].text).is_equal(
		"%d,%d" % [first, second]
	)
	# Golden: this seed's opening draws these two ranks.
	assert_array(loop.state.wild_ranks).is_equal(GOLDEN_WORKER)
	# A third is refused and spends nothing.
	var before: Dictionary = loop.state.to_dict()
	var commands: int = loop.record.commands.size()
	assert_int(loop.campaign_reason(0, none)).is_equal(CampaignEffect.Reason.WILD_FULL)
	assert_int(loop.player_campaign(0, none)).is_equal(RunLoop.Reason.ILLEGAL)
	assert_dict(loop.state.to_dict()).is_equal(before)
	assert_int(loop.record.commands.size()).is_equal(commands)
	assert_array(loop.state.inventory.consumables).is_equal(["model_worker"])


func test_model_worker_is_refused_once_the_first_play_is_made() -> void:
	var found: bool = false
	for seed_value: int in range(SEED, SEED + SEEDS):
		var loop: RunLoop = _loop(seed_value, ["model_worker"])
		var script: RunScript = RunScript.new()
		# Past the opening without using it, to the player's turn after a play.
		if not _drive(loop, _after_first_play, script):
			continue
		var none: Array[int] = []
		assert_int(loop.campaign_reason(0, none)).is_equal(CampaignEffect.Reason.PLAY_STARTED)
		assert_int(loop.player_campaign(0, none)).is_equal(RunLoop.Reason.ILLEGAL)
		assert_array(loop.state.wild_ranks).is_empty()
		found = true
		break
	assert_bool(found).is_true()


func test_model_worker_lasts_one_round() -> void:
	var loop: RunLoop = _loop(SEED, ["model_worker"])
	assert_bool(_drive(loop, _before_first_play)).is_true()
	var none: Array[int] = []
	assert_int(loop.player_campaign(0, none)).is_equal(RunLoop.Reason.OK)
	var round_index: int = loop.state.round_index
	var script: RunScript = RunScript.new()
	(
		assert_bool(
			_drive(
				loop, func(at: RunLoop) -> bool: return at.state.round_index > round_index, script
			)
		)
		. is_true()
	)
	assert_array(loop.state.wild_ranks).is_empty()
	_only_the_player_has_wild(loop, [])


func test_model_worker_replays_from_a_save_mid_round() -> void:
	var loop: RunLoop = _loop(SEED, ["model_worker", "model_worker"])
	assert_bool(_drive(loop, _before_first_play)).is_true()
	var none: Array[int] = []
	loop.player_campaign(0, none)
	loop.player_campaign(0, none)
	var script: RunScript = RunScript.new()
	for _turn: int in 3:
		script.act(loop)
	assert_int(loop.state.wild_ranks.size()).is_equal(2)
	var resumed: RunLoop = RunRecord.resume(_through_json(loop), RunScript.bots())
	assert_object(resumed).is_not_null()
	assert_array(resumed.state.wild_ranks).is_equal(loop.state.wild_ranks)
	assert_array(_log_lines(resumed)).is_equal(_log_lines(loop))
	_only_the_player_has_wild(resumed, loop.state.wild_ranks)


func test_mass_line_leaves_the_deal_as_it_was() -> void:
	for seed_value: int in range(SEED, SEED + 8):
		var plain: RunLoop = _loop(seed_value, [])
		var massed: RunLoop = _loop(seed_value, [], ["mass_line"])
		var plain_deal: DealResult = plain.get("_deal")
		var massed_deal: DealResult = massed.get("_deal")
		for seat: int in Seats.COUNT:
			var ids: Array[int] = []
			var other: Array[int] = []
			for card: CardInstance in plain_deal.hands[seat].cards():
				ids.append(card.id())
			for card: CardInstance in massed_deal.hands[seat].cards():
				other.append(card.id())
			assert_array(other).is_equal(ids)
		assert_array(plain.state.wild_ranks).is_empty()
		assert_int(massed.state.wild_ranks.size()).is_equal(1)


func test_mass_line_names_the_rank_before_anyone_bids() -> void:
	var loop: RunLoop = _loop(SEED, [], ["mass_line"])
	var kinds: Array[RunEvent.Type] = []
	for event: RunEvent in loop.events():
		kinds.append(event.type)
	var dealt: int = kinds.find(RunEvent.Type.DEALT)
	var named: int = kinds.find(RunEvent.Type.WILD_RANKS)
	assert_int(named).is_equal(dealt + 1)
	var bid: int = kinds.find(RunEvent.Type.BID)
	assert_bool(bid == -1 or bid > named).is_true()
	# Only the player's rules hold it during the bidding: a villager bids its cards of the
	# rank as plain cards.
	_only_the_player_has_wild(loop, loop.state.wild_ranks)


func test_mass_line_draws_a_rank_every_round_as_the_stream_gives() -> void:
	var params: SetParams = SetConfig.DEFAULT_PARAMS.duplicate()
	params.targets = params.targets.duplicate()
	params.targets.fill(1e12)
	var state: RunState = RunState.new(SEED)
	state.reforms.assign(["mass_line"])
	var loop: RunLoop = RunLoop.new(state, RunScript.bots(), SetConfig.new(params))
	loop.start_set()
	var drawn: Array[int] = []
	var script: RunScript = RunScript.new()
	for _step: int in 2000:
		if loop.state.round_index >= drawn.size() and not loop.state.wild_ranks.is_empty():
			drawn.append(loop.state.wild_ranks[0])
			assert_int(loop.state.wild_ranks.size()).is_equal(1)
		if drawn.size() >= GOLDEN_MASS_LINE.size() or not script.act(loop):
			break
	assert_array(drawn).is_equal(GOLDEN_MASS_LINE)
	# Over a Quota's rounds the draws differ, as the stream gives them.
	var seen: Dictionary[int, bool] = {}
	for rank: int in drawn:
		seen[rank] = true
	assert_int(seen.size()).is_greater(1)


func test_mass_line_and_model_worker_make_two_ranks_and_no_more() -> void:
	var loop: RunLoop = _loop(SEED, ["model_worker", "model_worker"], ["mass_line"])
	assert_bool(_drive(loop, _before_first_play)).is_true()
	assert_int(loop.state.wild_ranks.size()).is_equal(1)
	var none: Array[int] = []
	assert_int(loop.player_campaign(0, none)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.wild_ranks.size()).is_equal(2)
	assert_int(loop.campaign_reason(0, none)).is_equal(CampaignEffect.Reason.WILD_FULL)
	var script: RunScript = RunScript.new()
	for _turn: int in 2:
		script.act(loop)
	var resumed: RunLoop = RunRecord.resume(_through_json(loop), RunScript.bots())
	assert_object(resumed).is_not_null()
	assert_array(resumed.state.wild_ranks).is_equal(loop.state.wild_ranks)
	assert_array(_log_lines(resumed)).is_equal(_log_lines(loop))


func test_mass_line_replays_from_a_save_mid_round() -> void:
	var loop: RunLoop = _loop(SEED, [], ["mass_line"])
	var script: RunScript = RunScript.new()
	assert_bool(_drive(loop, _after_first_play, script)).is_true()
	var resumed: RunLoop = RunRecord.resume(_through_json(loop), RunScript.bots())
	assert_object(resumed).is_not_null()
	assert_array(resumed.state.wild_ranks).is_equal(loop.state.wild_ranks)
	assert_array(_log_lines(resumed)).is_equal(_log_lines(loop))
	_only_the_player_has_wild(resumed, loop.state.wild_ranks)


## A redeal draws Mass Line's rank again with the new deal, never adding a second.
func test_mass_line_draws_again_on_a_redeal() -> void:
	# Villagers who never bid, so a deal the player declines is dealt again.
	var shy: BotWeights = BotConfig.DEFAULT_WEIGHTS.duplicate()
	shy.call_threshold = 1e9
	shy.grab_threshold = 1e9
	var bots: Array[BotConfig] = []
	for _seat: int in Seats.COUNT:
		bots.append(BotConfig.new(shy, BotConfig.Tier.MEDIUM))
	for seed_value: int in range(SEED, SEED + SEEDS):
		var state: RunState = RunState.new(seed_value)
		state.reforms.assign(["mass_line"])
		var loop: RunLoop = RunLoop.new(state, bots, SetConfig.new())
		loop.start_set()
		var redealt: bool = false
		for _step: int in 40:
			if not _events_of(loop, RunEvent.Type.REDEALT).is_empty():
				redealt = true
				break
			if loop.awaiting() != RunLoop.Awaiting.PLAYER_BID:
				break
			loop.player_bid(false)
		if not redealt:
			continue
		assert_int(loop.state.wild_ranks.size()).is_equal(1)
		var named: Array[RunEvent] = _events_of(loop, RunEvent.Type.WILD_RANKS)
		assert_int(named.size()).is_greater(1)
		assert_int(loop.state.wild_ranks[0]).is_equal(named[-1].value)
		return
	fail("no seed redealt")


func test_the_three_items_are_tier_four_at_the_state_store() -> void:
	var worker: CampaignDef = null
	for campaign: CampaignDef in RunPools.STORE_CAMPAIGNS.campaigns:
		if campaign.id == "model_worker":
			worker = campaign
	assert_object(worker).is_not_null()
	assert_int(worker.cost).is_equal(3)
	assert_int(worker.unlock_tier).is_equal(RunUnlocks.WILD_TIER)
	assert_int(worker.tag).is_equal(ModifierDef.Tag.COLLECTIVE)
	assert_int(worker.when).is_equal(CampaignDef.When.OPENING)
	var costs: Dictionary[String, int] = {"mass_line": 10, "industrialization": 8}
	for reform_id: String in costs:
		var reform: ReformDef = RunDefinitions.reforms[reform_id]
		assert_int(reform.cost).is_equal(costs[reform_id])
		assert_int(reform.unlock_tier).is_equal(RunUnlocks.WILD_TIER)
	assert_bool(RunPools.MARKET_CAMPAIGNS.campaigns.any(_is_worker)).is_false()


func _is_worker(campaign: CampaignDef) -> bool:
	return campaign.id == "model_worker"
