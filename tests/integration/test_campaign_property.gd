extends GdUnitTestSuite
## A property over many seeds (ADR 0021): at random legal moments the player uses random
## held Campaigns on random cards while villagers of every tier play on. No villager
## makes an illegal action (the loop asserts on one, which fails the test), every card is
## where exactly one seat or the played pile says, hand sizes match the public view, and
## every round finishes.

const SEEDS: int = 24
const TIERS: Array[BotConfig.Tier] = [
	BotConfig.Tier.EASY, BotConfig.Tier.MEDIUM, BotConfig.Tier.HARD, BotConfig.Tier.EXPERT
]
## Decisions a Set may take before it counts as stuck.
const STEP_LIMIT: int = 900
const TRY_PERCENT: int = 40
## The expert searches a few samples here, so the test stays quick; its path is the one
## the game runs.
const EXPERT_SAMPLES: int = 4


func _configs(seed_value: int) -> Array[BotConfig]:
	var configs: Array[BotConfig] = [
		BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.MEDIUM)
	]
	for seat: int in [1, 2]:
		var tier: BotConfig.Tier = TIERS[(seed_value + seat * 3) % TIERS.size()]
		var weights: BotWeights = BotConfig.DEFAULT_WEIGHTS
		if tier == BotConfig.Tier.EXPERT:
			weights = BotConfig.DEFAULT_WEIGHTS.duplicate()
			weights.expert_samples = EXPERT_SAMPLES
			weights.expert_min_samples = 2
		configs.append(BotConfig.new(weights, tier))
	return configs


func test_random_campaigns_keep_every_round_legal_and_whole() -> void:
	var used: int = 0
	var tiers_seen: Dictionary[int, bool] = {}
	for seed_value: int in SEEDS:
		var configs: Array[BotConfig] = _configs(seed_value)
		tiers_seen[configs[1].tier] = true
		tiers_seen[configs[2].tier] = true
		var loop: RunLoop = RunLoop.new(RunState.new(seed_value + 100), configs, SetConfig.new())
		var stream: RandomStream = RandomStream.new(seed_value)
		loop.start_set()
		used += _play_set(loop, stream)
	assert_int(tiers_seen.size()).is_equal(TIERS.size())
	assert_int(used).is_greater(SEEDS)


## Plays one Set and returns how many Campaigns were used in it.
func _play_set(loop: RunLoop, stream: RandomStream) -> int:
	var script: RunScript = RunScript.new()
	var used: int = 0
	var round_index: int = -1
	for _step: int in STEP_LIMIT:
		if loop.state.round_index != round_index:
			round_index = loop.state.round_index
			_refill(loop, stream)
		if loop.round_state() != null:
			_check_round(loop)
		if _try_campaign(loop, stream):
			used += 1
			continue
		if not script.act(loop):
			break
	var over: Array[RunLoop.Awaiting] = [RunLoop.Awaiting.SET_OVER, RunLoop.Awaiting.RUN_OVER]
	assert_bool(over.has(loop.awaiting())).override_failure_message("stuck").is_true()
	return used


## Hands the player two random Campaigns for the round. Outside the commands, so this
## Set is never replayed.
func _refill(loop: RunLoop, stream: RandomStream) -> void:
	var all: Array[CampaignDef] = RunCampaigns.all()
	var held: Array[String] = []
	for _slot: int in 2:
		held.append(all[stream.next_int(0, all.size() - 1)].id)
	loop.state.inventory.consumables.assign(held)


func _try_campaign(loop: RunLoop, stream: RandomStream) -> bool:
	var held: Array[String] = loop.state.inventory.consumables
	if held.is_empty() or stream.next_int(0, 99) >= TRY_PERCENT:
		return false
	var slot: int = stream.next_int(0, held.size() - 1)
	var definition: CampaignDef = RunDefinitions.campaigns[held[slot]]
	var hand: Array[CardInstance] = loop.player_cards()
	var ids: Array[int] = []
	var count: int = mini(stream.next_int(definition.min_cards, definition.max_cards), hand.size())
	while ids.size() < count:
		var card_id: int = hand[stream.next_int(0, hand.size() - 1)].id()
		if not ids.has(card_id):
			ids.append(card_id)
	var expected: int = loop.campaign_reason(slot, ids)
	var was: int = loop.record.commands.size()
	var reason: RunLoop.Reason = loop.player_campaign(slot, ids)
	assert_bool(reason == RunLoop.Reason.OK).is_equal(expected == CampaignEffect.Reason.OK)
	if reason != RunLoop.Reason.OK:
		assert_int(loop.record.commands.size()).is_equal(was)
	return reason == RunLoop.Reason.OK


## Every deck card is in exactly one hand or on the played pile, and each hand's size is
## what the public view says.
func _check_round(loop: RunLoop) -> void:
	var round_state: RoundState = loop.round_state()
	var seen: Dictionary[int, bool] = {}
	var public: PublicView = round_state.public_view()
	for seat: int in Seats.COUNT:
		var cards: Array[CardInstance] = round_state.view_for(seat).own_cards
		assert_int(cards.size()).is_equal(public.remaining[seat])
		for card: CardInstance in cards:
			assert_bool(seen.has(card.id())).override_failure_message("twice").is_false()
			seen[card.id()] = true
	for event: RoundEvent in round_state.events():
		if event.type == RoundEvent.Type.PLAYED:
			for card_id: int in event.card_ids:
				assert_bool(seen.has(card_id)).override_failure_message("replayed").is_false()
				seen[card_id] = true
	assert_int(seen.size()).is_equal(Deck.SIZE)
	for card_id: int in seen:
		assert_bool(card_id >= 0 and card_id < Deck.SIZE).is_true()
