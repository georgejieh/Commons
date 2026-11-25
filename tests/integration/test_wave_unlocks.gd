extends GdUnitTestSuite
## ADR 0032's unlock tiers: a sixth tier, 5, opens after five finished runs; the wave's
## tier 4 and 5 pieces stay out of any run outside the profile, whose tiers stop at 3, and
## its tier 1 to 3 pieces join those runs' pools; the collection shows every new piece,
## locked until its tier.

const LATE: Array[String] = ["public_granary", "five_year_plan", "rent_book"]
const LAST: Array[String] = ["grain_speculator", "prize_exhibit"]
const EARLY: Array[String] = [
	"night_school",
	"iron_and_coal",
	"back_door",
	"advanced_cooperative",
	"double_share_plough",
	"open_accounts",
	"informers_reward",
	"tractor_station",
	"the_gleaners",
	"forged_seal",
	"loudspeaker",
]
const CAMPAIGNS: Array[String] = ["self_criticism", "relief_grain", "false_report"]


func _identity(finished: int, full: bool = true) -> RunIdentity:
	var identity: RunIdentity = RunIdentity.new()
	if full:
		identity.kind = RunIdentity.Kind.FULL
	identity.finished_runs = finished
	return identity


func _offered(pools: RunPools) -> Array[String]:
	var ids: Array[String] = []
	for cadre: ModifierDef in pools.store_cadres + pools.market_cadres:
		ids.append(cadre.id)
	for campaign: CampaignDef in pools.store_campaigns + pools.market_campaigns:
		ids.append(campaign.id)
	return ids


func test_the_last_tier_opens_after_five_finished_runs() -> void:
	assert_int(RunUnlocks.LAST_TIER).is_equal(5)
	for finished: int in [3, 4, 5]:
		var offered: Array[String] = _offered(RunPools.new(_identity(finished)))
		for item_id: String in LATE:
			assert_bool(offered.has(item_id)).override_failure_message(item_id).is_equal(
				finished >= 4
			)
		for item_id: String in LAST:
			assert_bool(offered.has(item_id)).override_failure_message(item_id).is_equal(
				finished >= 5
			)


func test_a_run_outside_the_profile_stays_at_tier_three_and_meets_the_early_pieces() -> void:
	var demo: RunIdentity = _identity(0, false)
	assert_int(RunUnlocks.open_tier(demo)).is_equal(3)
	var offered: Array[String] = _offered(RunPools.new(demo))
	for item_id: String in LATE + LAST:
		assert_bool(offered.has(item_id)).override_failure_message(item_id).is_false()
	for item_id: String in EARLY + CAMPAIGNS:
		assert_bool(offered.has(item_id)).override_failure_message(item_id).is_true()


## Each of the 21 pieces carries the ADR's tier, tag, cost and counter.
func test_every_piece_has_the_adrs_tier_tag_and_cost() -> void:
	# id: [tier, private, cost]
	var cadres: Dictionary[String, Array] = {
		"night_school": [1, false, 4],
		"iron_and_coal": [1, false, 4],
		"advanced_cooperative": [2, false, 5],
		"double_share_plough": [2, false, 5],
		"open_accounts": [2, false, 4],
		"tractor_station": [3, false, 5],
		"the_gleaners": [3, false, 5],
		"public_granary": [4, false, 6],
		"five_year_plan": [4, false, 6],
		"back_door": [1, true, 4],
		"informers_reward": [2, true, 4],
		"forged_seal": [3, true, 5],
		"loudspeaker": [3, true, 5],
		"rent_book": [4, true, 6],
		"grain_speculator": [5, true, 5],
		"prize_exhibit": [5, true, 5],
	}
	var store: Array[ModifierDef] = RunPools.STORE_CADRES.cadres
	var market: Array[ModifierDef] = RunPools.MARKET_CADRES.cadres
	for definition: ModifierDef in store + market:
		if not cadres.has(definition.id):
			continue
		var row: Array = cadres[definition.id]
		assert_int(definition.unlock_tier).override_failure_message(definition.id).is_equal(row[0])
		var private: bool = definition.tag == ModifierDef.Tag.PRIVATE
		assert_bool(private).override_failure_message(definition.id).is_equal(row[1])
		assert_bool(market.has(definition)).is_equal(row[1])
		assert_int(definition.cost).is_equal(row[2])
		cadres.erase(definition.id)
	assert_dict(cadres).is_empty()
	var campaigns: Dictionary[String, Array] = {
		"self_criticism": [1, false, 3, CampaignDef.When.TURN_OR_SHOP],
		"relief_grain": [2, false, 4, CampaignDef.When.TURN_OR_SHOP],
		"false_report": [3, true, 4, CampaignDef.When.TURN],
	}
	for definition: CampaignDef in RunCampaigns.all():
		if not campaigns.has(definition.id):
			continue
		var row: Array = campaigns[definition.id]
		var got: Array = [
			definition.unlock_tier,
			definition.tag == ModifierDef.Tag.PRIVATE,
			definition.cost,
			definition.when,
		]
		assert_array(got).override_failure_message(definition.id).is_equal(row)
		var pool: Array[CampaignDef] = RunPools.MARKET_CAMPAIGNS.campaigns
		if not row[1]:
			pool = RunPools.STORE_CAMPAIGNS.campaigns
		assert_bool(pool.has(definition)).is_true()
		campaigns.erase(definition.id)
	assert_dict(campaigns).is_empty()


## A blank sheet with only its tier until it opens, then its name and rules.
func test_the_collection_shows_the_new_pieces_locked_until_their_tier() -> void:
	var pieces: Array[String] = []
	pieces.assign(EARLY + LATE + LAST + CAMPAIGNS)
	var tiers: Dictionary[String, int] = {}
	for cadre: ModifierDef in RunLoop.all_cadres():
		tiers[cadre.id] = cadre.unlock_tier
	for campaign: CampaignDef in RunCampaigns.all():
		tiers[campaign.id] = campaign.unlock_tier
	for finished: int in [0, 3, 5]:
		var view: CollectionView = CollectionView.for_runs(finished)
		var open: Dictionary[String, bool] = {}
		var locked: int = 0
		for section: int in [
			CollectionView.COLLECTIVE, CollectionView.PRIVATE, CollectionView.CAMPAIGNS
		]:
			for sheet: UnlockSheet in view.sheets(section):
				if sheet.open:
					open[sheet.id] = true
				else:
					locked += 1
		var expected_locked: int = 0
		for item_id: String in tiers:
			if tiers[item_id] > finished:
				expected_locked += 1
		assert_int(locked).override_failure_message(str(finished)).is_equal(expected_locked)
		for item_id: String in pieces:
			assert_bool(open.has(item_id)).is_equal(tiers[item_id] <= finished)
	assert_int(CollectionView.for_runs(5).open_count()).is_equal(CollectionView.for_runs(5).total())
