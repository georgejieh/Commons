extends GdUnitTestSuite
## P4.6 Done-when: a villager bombed repeatedly in one run opens the next run
## differently. The previous run's memory goes through the real profile save and the
## controller's carry into a new run; the new runs replay the same seeds with and without
## it, and Zhao's answers to the player's tricks in the opening Set are counted.

const SEEDS: Array[int] = [4601, 4602, 4603, 4604, 4605, 4606, 4607, 4608, 4609, 4610]
const PATH: String = "user://test_memory_runs_profile.json"
const ZHAO: String = "zhao"
const BOMBS_LAST_RUN: int = 12


func after_test() -> void:
	for path: String in [PATH, PATH + SaveService.BACKUP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _configs() -> Array[BotConfig]:
	var village: VillageBook = RunLoop.DEFAULT_VILLAGE
	return [
		BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.MEDIUM),
		BotConfig.from_personality(village.family(ZHAO).personality, 11),
		BotConfig.from_personality(village.family("li").personality, 12),
	]


## Zhao's plays and passes when the player owns the trick, over each seed's first Set.
func _zhao_answers(profile: SaveService) -> int:
	var answered: int = 0
	for seed_value: int in SEEDS:
		var controller: RunController = auto_free(RunController.new())
		controller.start_run(seed_value, _configs(), SetConfig.new(), null, 0, profile)
		var loop: RunLoop = controller.get("_loop")
		loop.state.table.assign(["player", ZHAO, "li"])
		var script: RunScript = RunScript.new()
		script.play_until_set_over(loop)
		var owner: int = Seats.NONE
		for event: RunEvent in loop.events():
			var played: RoundEvent = event.round_event
			if played == null:
				continue
			if played.type == RoundEvent.Type.TRICK_WON:
				owner = Seats.NONE
			elif played.type == RoundEvent.Type.PLAYED:
				if played.seat == 1 and owner == 0:
					answered += 1
				owner = played.seat
	return answered


func test_a_bombed_family_opens_the_next_run_more_hostile() -> void:
	var calm: int = _zhao_answers(null)
	var last_run: VillageMemory = VillageMemory.new()
	var summary: SetSummary = SetSummary.new(0)
	summary.add(ZHAO, SetSummary.Kind.BOMBED, BOMBS_LAST_RUN)
	last_run.record(summary)
	var profile: SaveService = Profile.service(PATH)
	Profile.save_memory(profile, last_run)
	var carried: VillageMemory = Profile.memory(profile).carried(RunLoop.DEFAULT_MEMORY)
	assert_float(carried.pull(ZHAO, RunLoop.DEFAULT_MEMORY)).is_greater(0.0)
	var remembered: int = _zhao_answers(profile)
	print("zhao answers the player's tricks: %d fresh, %d after being bombed" % [calm, remembered])
	assert_int(remembered).is_greater(calm)


func test_a_run_that_dies_mid_set_still_remembers_that_set() -> void:
	var remembered: int = 0
	for seed_value: int in range(3600, 3620):
		var state: RunState = RunState.new(seed_value)
		var loop: RunLoop = RunLoop.new(state, RunScript.bots(), _unmeetable())
		var script: RunScript = RunScript.new()
		loop.start_set()
		while loop.awaiting() != RunLoop.Awaiting.PLAYER_NEED:
			if loop.awaiting() == RunLoop.Awaiting.SET_OVER or not script.act(loop):
				break
		if loop.awaiting() != RunLoop.Awaiting.PLAYER_NEED:
			continue
		# One point short of starving, then a claim the Commons can't cover.
		state.famine = RunLoop.DEFAULT_METERS.famine.death - 1
		loop.player_need(Banking.MAX_NEED)
		if loop.awaiting() != RunLoop.Awaiting.RUN_OVER:
			continue
		var summary: SetSummary = state.summaries[-1]
		for family_id: String in summary.counts:
			for kind: int in SetSummary.KIND_COUNT:
				var kept: float = state.memory.count(family_id, kind as SetSummary.Kind)
				assert_float(kept).is_equal_approx(float(summary.counts[family_id][kind]), 0.001)
				if summary.counts[family_id][kind] > 0.0:
					remembered += 1
	assert_int(remembered).is_greater(0)


## Sets whose Quota can't be met, so a Set never ends early.
func _unmeetable() -> SetConfig:
	var params: SetParams = SetConfig.DEFAULT_PARAMS.duplicate()
	params.targets = params.targets.duplicate()
	params.targets.fill(1e9)
	return SetConfig.new(params)
