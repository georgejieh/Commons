extends GdUnitTestSuite
## Generations (ADR 0028, P4.17): the village's drift is the same for the same profile,
## accumulates over the generations a step at a time within LOW..HIGH, shifts a voice's
## pitch no more than the limit, never changes the shared definitions, and is applied
## only to a full run, through the profile's once-only write at a run's start; the demo
## and the arrival drift nothing, youth never drift, and a schema 2 profile migrates
## with none.

const DIR: String = "user://test_village_drift/"
const PROFILE_PATH: String = DIR + "profile.json"
const START_TIME: int = 1_763_200_000
const VILLAGE: VillageBook = preload("res://data/villagers/village.tres")
const GENERATIONS: int = 60

var _profile: SaveService


func before_test() -> void:
	_profile = Profile.service(PROFILE_PATH)
	_profile.delete()


func after_test() -> void:
	_profile.delete()


func _through(last: int, village: VillageBook = VILLAGE) -> VillageDrift:
	var drift: VillageDrift = VillageDrift.new()
	for generation: int in range(1, last + 1):
		drift = VillageDrift.next(drift, generation, village)
	return drift


func test_the_same_profile_gives_the_same_village() -> void:
	assert_dict(_through(12).to_dict()).is_equal(_through(12).to_dict())
	assert_dict(_through(12).to_dict()).is_not_equal(_through(13).to_dict())


func test_the_first_generation_is_the_village_as_defined() -> void:
	assert_bool(_through(1).is_empty()).is_true()
	assert_bool(_through(2).is_empty()).is_false()


func test_drift_accumulates_a_step_at_a_time_and_stays_in_range() -> void:
	var drift: VillageDrift = VillageDrift.new()
	var moved: int = 0
	for generation: int in range(1, GENERATIONS + 1):
		var next: VillageDrift = VillageDrift.next(drift, generation, VILLAGE)
		for family: FamilyDef in VILLAGE.families:
			var drifted: Personality = next.personality(family)
			for trait_name: String in VillageDrift.TRAITS:
				var now: int = next.offset(family.id, trait_name)
				var step: int = now - drift.offset(family.id, trait_name)
				assert_int(absi(step)).is_less_equal(1)
				moved += absi(step)
				var level: int = int(family.personality.get(trait_name)) + now
				assert_int(level).is_between(Personality.Level.LOW, Personality.Level.HIGH)
				assert_int(int(drifted.get(trait_name))).is_equal(level)
			var shift: float = absf(next.pitch_factor(family.id) - 1.0)
			assert_float(shift).is_less_equal(VILLAGE.pitch_limit + 1e-9)
		drift = next
	# About 15% of 5 levels of 14 families over 59 generations moves, less those off an end.
	assert_int(moved).is_greater(100)


func test_the_pitch_shift_is_clamped() -> void:
	var wild: VillageBook = VILLAGE.duplicate() as VillageBook
	wild.pitch_step = 0.5
	var drift: VillageDrift = _through(30, wild)
	var at_limit: int = 0
	for family: FamilyDef in wild.families:
		var shift: float = absf(drift.pitch_factor(family.id) - 1.0)
		assert_float(shift).is_less_equal(wild.pitch_limit + 1e-9)
		at_limit += 1 if is_equal_approx(shift, wild.pitch_limit) else 0
	assert_int(at_limit).is_greater(0)


func test_drift_never_changes_the_shared_definitions() -> void:
	var before: Array = []
	for family: FamilyDef in VILLAGE.families:
		var levels: Array[int] = []
		for trait_name: String in VillageDrift.TRAITS:
			levels.append(int(family.personality.get(trait_name)))
		before.append([levels, family.voice.pitch if family.voice != null else 0.0])
	var drift: VillageDrift = _through(40)
	var state: RunState = RunState.new(3)
	state.drift = drift
	Roster.start(state, VILLAGE, [])
	state.table = ["player", state.roster[0].family_id, state.roster[1].family_id]
	for seat: int in [1, 2]:
		RunPeople.seat_voice(state, seat)
	for entry: RosterEntry in state.roster:
		Roster.config_for(VILLAGE, entry, 1, drift)
		drift.personality(Roster.definition(VILLAGE, entry))
	for index: int in VILLAGE.families.size():
		var family: FamilyDef = VILLAGE.families[index]
		var levels: Array[int] = []
		for trait_name: String in VillageDrift.TRAITS:
			levels.append(int(family.personality.get(trait_name)))
		var pitch: float = family.voice.pitch if family.voice != null else 0.0
		assert_array([levels, pitch]).is_equal(before[index])


func test_a_seated_family_plays_and_speaks_as_it_drifted() -> void:
	var drift: VillageDrift = _through(40)
	var state: RunState = RunState.new(3)
	state.drift = drift
	Roster.start(state, VILLAGE, [])
	var found: bool = false
	for entry: RosterEntry in state.roster:
		var family: FamilyDef = VILLAGE.family(entry.family_id)
		var drifted: BotConfig = Roster.config_for(VILLAGE, entry, 1, drift)
		var plain: BotConfig = Roster.config_for(VILLAGE, entry, 1)
		var expected: BotConfig = BotConfig.from_personality(drift.personality(family), 1)
		assert_float(drifted.cooperation).is_equal(expected.cooperation)
		assert_float(drifted.honesty).is_equal(expected.honesty)
		found = found or drifted.cooperation != plain.cooperation or drifted.grudge != plain.grudge
		state.table = ["player", entry.family_id, entry.family_id]
		var voice: VoiceProfile = RunPeople.seat_voice(state, 1)
		if voice != null:
			var pitch: float = family.voice.pitch * drift.pitch_factor(family.id)
			assert_float(voice.pitch).is_equal_approx(pitch, 1e-6)
			var factor: float = drift.pitch_factor(family.id)
			assert_float(voice.playback_pitch).is_equal_approx(factor, 1e-9)
			var plan: VoicePlan = VoiceScript.plan("Go on.", "", voice)
			var flat: VoicePlan = VoiceScript.plan("Go on.", "", family.voice)
			assert_float(plan.pitches[0]).is_equal_approx(flat.pitches[0] * factor, 1e-5)
	assert_bool(found).is_true()


func test_youth_never_drift() -> void:
	var drift: VillageDrift = _through(40)
	var youth: RosterEntry = RosterEntry.new("youth_0")
	youth.template_id = VILLAGE.youth_templates[0].id
	youth.name_key = VILLAGE.youth_surnames[0]
	var template: FamilyDef = VILLAGE.youth_templates[0]
	var config: BotConfig = Roster.config_for(VILLAGE, youth, 1, drift)
	var plain: BotConfig = BotConfig.from_personality(template.personality, 1)
	assert_float(config.cooperation).is_equal(plain.cooperation)
	assert_float(config.grudge).is_equal(plain.grudge)


func test_a_full_run_takes_the_generations_drift_in_the_starting_write() -> void:
	for generation: int in range(1, 6):
		var request: RunRequest = RunRequest.new(RunRequest.FULL, generation, START_TIME)
		var state: RunState = RunStarter.state(request, _profile)
		var data: ProfileData = Profile.read(_profile)
		assert_int(data.generation).is_equal(generation)
		assert_dict(data.drift.to_dict()).is_equal(_through(generation).to_dict())
		assert_dict(state.drift.to_dict()).is_equal(data.drift.to_dict())


func test_the_demo_and_the_arrival_drift_nothing() -> void:
	var data: ProfileData = ProfileData.new()
	data.generation = 7
	data.drift = _through(7)
	Profile.write(_profile, data)
	var request: RunRequest = RunRequest.new(RunRequest.DEMO, 4, START_TIME)
	var demo: RunState = RunStarter.state(request, _profile)
	assert_bool(demo.drift.is_empty()).is_true()
	var tutorial: RunState = RunStarter.state(RunStarter.tutorial())
	assert_bool(tutorial.drift.is_empty()).is_true()
	assert_dict(Profile.read(_profile).drift.to_dict()).is_equal(data.drift.to_dict())


func test_a_schema_2_profile_migrates_with_no_drift() -> void:
	var old: Dictionary = ProfileData.new().to_dict()
	old.erase("drift")
	old["generation"] = 4
	old["surname"] = "Yuan"
	SaveService.new(PROFILE_PATH, {}, 2).save(old)
	var data: ProfileData = Profile.read(_profile)
	assert_int(data.generation).is_equal(4)
	assert_str(data.surname).is_equal("Yuan")
	assert_bool(data.drift.is_empty()).is_true()
	assert_int(Profile.SCHEMA_VERSION).is_equal(3)


func test_a_damaged_drift_fails_validation() -> void:
	var data: Dictionary = ProfileData.new().to_dict()
	data["drift"] = {"wang": {"levels": {"honesty": 1}, "pitch": RunState.float_text(0.02)}}
	assert_bool(ProfileData.is_valid(data)).is_true()
	for bad: Variant in [
		[],
		{"wang": {"levels": {"honesty": 1.5}, "pitch": RunState.float_text(0.0)}},
		{"wang": {"levels": {"charm": 1}, "pitch": RunState.float_text(0.0)}},
		{"wang": {"levels": {}, "pitch": 0.02}},
		{"wang": {"levels": {"honesty": 3}, "pitch": RunState.float_text(0.0)}},
	]:
		data["drift"] = bad
		assert_bool(ProfileData.is_valid(data)).override_failure_message(str(bad)).is_false()
