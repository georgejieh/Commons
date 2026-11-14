extends GdUnitTestSuite
## P4.7: boss Sets alternate between officials and risen villagers, fall back to
## officials, end with the New Landlord, and the New Landlord copies the player's style.

const POOL: BossPool = preload("res://data/run/boss_pool.tres")
const YEARS: int = 8


func _boss_for(state: RunState, year: int) -> ModifierDef:
	state.year = year
	return Bosses.choose(state, POOL, YEARS, RandomStream.new(year))


func test_officials_and_risen_villagers_alternate_and_the_last_is_the_new_landlord() -> void:
	var state: RunState = RunState.new(1)
	state.risen.assign(["zhao", "chen", "tang"])
	for year: int in range(1, YEARS + 1):
		var boss: ModifierDef = _boss_for(state, year)
		if year == YEARS:
			assert_object(boss).is_same(POOL.new_landlord)
		elif year % 2 == 0:
			assert_object(boss).override_failure_message("year %d" % year).is_same(POOL.risen)
			assert_bool(state.risen.has(state.boss_family)).is_true()
		else:
			(
				assert_bool(POOL.officials.has(boss))
				. override_failure_message("year %d" % year)
				. is_true()
			)
	assert_int(state.risen_used.size()).is_equal(3)


func test_with_no_risen_villager_an_official_runs_the_set() -> void:
	var state: RunState = RunState.new(2)
	assert_bool(POOL.officials.has(_boss_for(state, 2))).is_true()
	state.risen.assign(["zhao"])
	assert_object(_boss_for(state, 4)).is_same(POOL.risen)
	# Zhao has had their turn, so the next even Year falls back.
	assert_bool(POOL.officials.has(_boss_for(state, 6))).is_true()


func test_officials_do_not_repeat_until_all_have_run() -> void:
	var state: RunState = RunState.new(3)
	var seen: Array[String] = []
	for index: int in POOL.officials.size():
		var boss: ModifierDef = _boss_for(state, 1)
		assert_bool(seen.has(boss.id)).is_false()
		seen.append(boss.id)
	assert_bool(POOL.officials.has(_boss_for(state, 1))).is_true()


func test_only_a_villager_holding_every_round_has_risen() -> void:
	var table: Array[String] = ["player", "zhao", "li"]
	var held: Array[RunEvent] = [
		RunEvent.new(RunEvent.Type.SEAT_KEPT, 1),
		RunEvent.new(RunEvent.Type.SEAT_KEPT, 1),
		RunEvent.new(RunEvent.Type.SEAT_LOST, 1),
	]
	assert_str(Bosses.full_set_holder(held, table, 0)).is_equal("zhao")
	var shared: Array[RunEvent] = [
		RunEvent.new(RunEvent.Type.SEAT_LOST, 1), RunEvent.new(RunEvent.Type.SEAT_KEPT, 2)
	]
	assert_str(Bosses.full_set_holder(shared, table, 0)).is_equal(Bosses.NO_FAMILY)
	var player: Array[RunEvent] = [RunEvent.new(RunEvent.Type.SEAT_KEPT, 0)]
	assert_str(Bosses.full_set_holder(player, table, 0)).is_equal(Bosses.NO_FAMILY)


func test_the_purge_destroys_held_cadres() -> void:
	var inventory: RunInventory = RunInventory.new()
	inventory.cadres.assign(["a", "b", "c"])
	var destroyed: Array[String] = Bosses.purge(inventory, 1, RandomStream.new(4))
	assert_int(destroyed.size()).is_equal(1)
	assert_int(inventory.cadres.size()).is_equal(2)
	assert_bool(inventory.cadres.has(destroyed[0])).is_false()
	assert_array(Bosses.purge(RunInventory.new(), 1, RandomStream.new(4))).is_empty()


func _style(pairs: int, singles: int, calls: int, turns: int) -> PlayerStyle:
	var style: PlayerStyle = PlayerStyle.new()
	style.type_counts[Pattern.Type.PAIR] = pairs
	style.type_counts[Pattern.Type.SINGLE] = singles
	style.calls = calls
	style.bid_turns = turns
	return style


func test_the_new_landlord_takes_the_players_hand_types_and_bid_rate() -> void:
	var styles: Array[PlayerStyle] = [_style(6, 2, 3, 3), _style(6, 2, 2, 2), _style(3, 1, 3, 3)]
	var config: BotConfig = BotConfig.new()
	PlayerStyle.mirror(config, styles, POOL)
	assert_float(config.type_bias[Pattern.Type.PAIR]).is_equal_approx(0.75 * POOL.style_bias, 1e-5)
	assert_float(config.type_bias[Pattern.Type.SINGLE]).is_equal_approx(
		0.25 * POOL.style_bias, 1e-5
	)
	assert_float(config.type_bias[Pattern.Type.BOMB]).is_equal(0.0)
	assert_float(config.ambition).is_equal_approx(0.5 * POOL.ambition_span, 1e-6)
	var shy: BotConfig = BotConfig.new()
	PlayerStyle.mirror(shy, [_style(1, 1, 0, 4)], POOL)
	assert_float(shy.ambition).is_equal_approx(-0.5 * POOL.ambition_span, 1e-6)


func test_a_bias_raises_only_its_hand_types_score() -> void:
	var rules: RuleSet = RuleSet.default_rules()
	var map: PackedByteArray = Ranks.identity_map()
	var table: BotTable = BotTable.new(rules, map)
	var counts: PackedByteArray = RankText.counts("33456789TJ")
	var bias: PackedFloat32Array = PackedFloat32Array()
	bias.resize(Pattern.Type.size())
	bias[Pattern.Type.PAIR] = 2.0
	var plain: CandidateScorer = CandidateScorer.new(counts, table, BotConfig.DEFAULT_WEIGHTS)
	var biased: CandidateScorer = CandidateScorer.new(
		counts, table, BotConfig.DEFAULT_WEIGHTS, bias
	)
	var pair: Pattern = Classifier.classify(RankText.counts("33"), rules, map).pattern
	var single: Pattern = Classifier.classify(RankText.counts("9"), rules, map).pattern
	assert_float(biased.score_play(pair) - plain.score_play(pair)).is_equal_approx(2.0, 1e-6)
	assert_float(biased.score_play(single)).is_equal_approx(plain.score_play(single), 1e-6)


func test_the_players_style_is_read_from_a_sets_log() -> void:
	var rules: RuleSet = RuleSet.default_rules()
	var pair: Pattern = (
		Classifier.classify(RankText.counts("33"), rules, Ranks.identity_map()).pattern
	)
	var played: RoundEvent = RoundEvent.new(RoundEvent.Type.PLAYED, 0, [], pair)
	var events: Array[RunEvent] = [
		RunEvent.new(RunEvent.Type.BID, 0, 1),
		RunEvent.new(RunEvent.Type.BID, 0, 0),
		RunEvent.new(RunEvent.Type.BID, 1, 1),
		RunEvent.wrap(played),
	]
	var style: PlayerStyle = PlayerStyle.from_events(events, 0)
	assert_int(style.bid_turns).is_equal(2)
	assert_int(style.calls).is_equal(1)
	assert_int(style.type_counts[Pattern.Type.PAIR]).is_equal(1)
	assert_dict(PlayerStyle.from_dict(style.to_dict()).to_dict()).is_equal(style.to_dict())


func test_a_risen_villager_away_in_reeducation_is_not_seated_as_the_boss() -> void:
	var state: RunState = RunState.new(21)
	state.risen.assign(["zhao"])
	var away: RosterEntry = RosterEntry.new("zhao")
	away.status = RosterEntry.Status.REEDUCATION
	state.roster.append(away)
	assert_object(_boss_for(state, 4)).is_not_same(POOL.risen)
	assert_str(state.boss_family).is_empty()
	away.status = RosterEntry.Status.ACTIVE
	assert_object(_boss_for(state, 4)).is_same(POOL.risen)
	assert_str(state.boss_family).is_equal("zhao")


func test_the_new_landlord_plays_at_medium_or_above_so_the_mirror_shows() -> void:
	var config: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.EASY)
	var styles: Array[PlayerStyle] = [_style(8, 1, 2, 4)]
	PlayerStyle.mirror(config, styles, POOL)
	assert_int(config.tier).is_equal(BotConfig.Tier.MEDIUM)
	var hard: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.HARD)
	PlayerStyle.mirror(hard, styles, POOL)
	assert_int(hard.tier).is_equal(BotConfig.Tier.HARD)
