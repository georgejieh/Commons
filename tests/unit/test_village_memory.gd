extends GdUnitTestSuite
## P4.6: the village's memory builds from Set summaries, fades by the data rate at each
## new run, weighs each kind by data, and survives in the profile save.

const PARAMS: MemoryParams = preload("res://data/villagers/memory.tres")
const PATH: String = "user://test_memory_profile.json"


func after_test() -> void:
	for path: String in [PATH, PATH + SaveService.BACKUP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _summary(family_id: String, kind: SetSummary.Kind, amount: int) -> SetSummary:
	var summary: SetSummary = SetSummary.new(0)
	summary.add(family_id, kind, amount)
	return summary


func test_set_summaries_add_up() -> void:
	var memory: VillageMemory = VillageMemory.new()
	memory.record(_summary("zhao", SetSummary.Kind.BOMBED, 2))
	memory.record(_summary("zhao", SetSummary.Kind.BOMBED, 3))
	memory.record(_summary("li", SetSummary.Kind.FED, 1))
	assert_float(memory.count("zhao", SetSummary.Kind.BOMBED)).is_equal(5.0)
	assert_float(memory.count("li", SetSummary.Kind.FED)).is_equal(1.0)
	assert_float(memory.count("wang", SetSummary.Kind.FED)).is_equal(0.0)


func test_each_new_run_keeps_the_data_share() -> void:
	var memory: VillageMemory = VillageMemory.new()
	memory.record(_summary("zhao", SetSummary.Kind.BOMBED, 8))
	var next: VillageMemory = memory.carried(PARAMS)
	assert_float(next.count("zhao", SetSummary.Kind.BOMBED)).is_equal(8.0 * PARAMS.kept_per_run)
	assert_float(memory.count("zhao", SetSummary.Kind.BOMBED)).is_equal(8.0)


func test_the_grudge_weighs_each_kind_and_feeding_softens_it() -> void:
	var memory: VillageMemory = VillageMemory.new()
	memory.record(_summary("zhao", SetSummary.Kind.BOMBED, 2))
	memory.record(_summary("zhao", SetSummary.Kind.BETRAYED, 1))
	memory.record(_summary("zhao", SetSummary.Kind.FED, 1))
	var expected: float = 2 * PARAMS.bombed_weight + PARAMS.betrayed_weight + PARAMS.fed_weight
	assert_float(memory.grudge("zhao", PARAMS)).is_equal_approx(expected, 1e-9)


func test_the_pull_runs_from_zero_to_one() -> void:
	var memory: VillageMemory = VillageMemory.new()
	memory.record(_summary("li", SetSummary.Kind.FED, 50))
	memory.record(_summary("zhao", SetSummary.Kind.BOMBED, 500))
	assert_float(memory.pull("li", PARAMS)).is_equal(0.0)
	assert_float(memory.pull("zhao", PARAMS)).is_equal(1.0)
	assert_float(memory.pull("nobody", PARAMS)).is_equal(0.0)


func test_memory_round_trips_through_the_profile_save() -> void:
	var memory: VillageMemory = VillageMemory.new()
	memory.record(_summary("zhao", SetSummary.Kind.BOMBED, 3))
	memory = memory.carried(PARAMS)
	var profile: SaveService = Profile.service(PATH)
	profile.save({"other": 7})
	assert_int(Profile.save_memory(profile, memory)).is_equal(OK)
	var loaded: VillageMemory = Profile.memory(profile)
	assert_dict(loaded.to_dict()).is_equal(memory.to_dict())
	assert_int(int(profile.load_save().data["other"])).is_equal(7)


func test_a_missing_or_damaged_profile_remembers_nothing() -> void:
	var profile: SaveService = Profile.service(PATH)
	assert_dict(Profile.memory(profile).to_dict()).is_empty()
	profile.save({Profile.MEMORY_KEY: {"zhao": [1]}})
	assert_dict(Profile.memory(profile).to_dict()).is_empty()
