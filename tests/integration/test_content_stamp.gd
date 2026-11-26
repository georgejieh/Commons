extends GdUnitTestSuite
## A run save keeps the stamp of the content it was written against, and a save from other
## content, or one whose commands no longer apply, resumes at its checkpoint (ADR 0033).

const SEED: int = 3701
const PATH: String = "user://test_content_stamp/run.json"
const OTHER: String = "0.0.0:another build"


func _service() -> SaveService:
	var service: SaveService = SaveService.for_run(PATH)
	service.delete()
	return service


## A controller played through its first Quota into the store, with one Cadre bought.
func _in_the_store(service: SaveService) -> RunController:
	var controller: RunController = auto_free(RunController.new())
	controller.start_run(SEED, RunScript.bots(), SetConfig.new(), service, 20)
	var script: ControllerScript = ControllerScript.new()
	while script.act(controller):
		pass
	controller.finish_set()
	assert_int(controller.buy(0)).is_equal(RunController.OK)
	return controller


## Writes the save again as another build would have: the same data, its stamp changed.
func _restamp(service: SaveService, stamp: Variant, commands: Array = []) -> void:
	var loaded: SaveLoad = service.load_save()
	var extras: Dictionary = loaded.extras.duplicate()
	if stamp == null:
		extras.erase(ContentStamp.KEY)
	else:
		extras[ContentStamp.KEY] = stamp
	var data: Dictionary = loaded.data.duplicate(true)
	var kept: Array = data["commands"]
	kept.append_array(commands)
	assert_int(service.save(data, extras)).is_equal(OK)


func _resumed(service: SaveService) -> RunController:
	var resumed: RunController = auto_free(RunController.new())
	assert_bool(resumed.resume_saved(service, RunScript.bots(), SetConfig.new())).is_true()
	return resumed


func test_a_save_keeps_this_builds_stamp() -> void:
	var service: SaveService = _service()
	_in_the_store(service)
	assert_str(str(service.kept_extras()[ContentStamp.KEY])).is_equal(ContentStamp.current())
	assert_bool(ContentStamp.matches(service.load_save().extras)).is_true()
	service.delete()


func test_a_save_of_this_build_replays_its_commands() -> void:
	var service: SaveService = _service()
	var controller: RunController = _in_the_store(service)
	var resumed: RunController = _resumed(service)
	assert_int(resumed.awaiting()).is_equal(RunController.AWAIT_STORE)
	assert_array(resumed.state_copy().inventory.cadres).is_equal(
		controller.state_copy().inventory.cadres
	)
	service.delete()


## The purchase was made against another build's shelf, so it is left out: the run stands
## where its Quota ended, before the store, with the coupons it had then.
func test_a_save_from_other_content_resumes_at_its_checkpoint() -> void:
	for stamp: Variant in [OTHER, null]:
		var service: SaveService = _service()
		var controller: RunController = _in_the_store(service)
		var held: Array[String] = controller.state_copy().inventory.cadres
		assert_array(held).is_not_empty()
		_restamp(service, stamp)
		var resumed: RunController = _resumed(service)
		assert_int(resumed.awaiting()).is_equal(RunController.AWAIT_SET_OVER)
		assert_array(resumed.state_copy().inventory.cadres).is_empty()
		assert_int(resumed.state_copy().set_index).is_equal(controller.state_copy().set_index)
		# It goes on from there, and its next save is this build's and replays whole.
		resumed.finish_set()
		assert_int(resumed.awaiting()).is_equal(RunController.AWAIT_STORE)
		assert_bool(ContentStamp.matches(service.load_save().extras)).is_true()
		assert_int(_resumed(service).awaiting()).is_equal(RunController.AWAIT_STORE)
		service.delete()


## Mid-round, another build's save starts its Quota again from the first deal.
func test_a_round_from_other_content_starts_its_quota_again() -> void:
	var service: SaveService = _service()
	var controller: RunController = auto_free(RunController.new())
	controller.start_run(SEED, RunScript.bots(), SetConfig.new(), service, 20)
	var script: ControllerScript = ControllerScript.new()
	var acted: int = 0
	while acted < 6 and script.act(controller):
		acted += 1
	assert_array(service.load_save().data["commands"]).is_not_empty()
	_restamp(service, OTHER)
	var resumed: RunController = _resumed(service)
	var state: RunState = resumed.state_copy()
	assert_int(state.set_index).is_equal(0)
	assert_int(state.round_index).is_equal(0)
	assert_float(state.set_progress).is_equal(0.0)
	service.delete()


## A command that no longer applies does not strand the run: it resumes at the checkpoint.
func test_a_save_whose_commands_no_longer_apply_resumes_at_its_checkpoint() -> void:
	var service: SaveService = _service()
	_in_the_store(service)
	_restamp(service, ContentStamp.current(), [{"type": "buy", "slot": 99}])
	var resumed: RunController = _resumed(service)
	assert_int(resumed.awaiting()).is_equal(RunController.AWAIT_SET_OVER)
	assert_array(resumed.state_copy().inventory.cadres).is_empty()
	service.delete()


## The villagers a Quota seats and the bosses it may face are drawn after the
## checkpoint too, so both are in what the stamp reads (ADR 0033).
func test_the_stamp_reads_the_village_and_every_boss() -> void:
	var drawn: Array[Resource] = ContentStamp.drawn()
	for boss: ModifierDef in RunPools.BOSSES.all():
		assert_bool(drawn.has(boss)).override_failure_message(boss.id).is_true()
	assert_bool(drawn.has(RunPools.BOSSES)).is_true()
	assert_bool(drawn.has(RunDefaults.VILLAGE)).is_true()
	for family: FamilyDef in RunDefaults.VILLAGE.families:
		assert_bool(drawn.has(family)).override_failure_message(family.id).is_true()
		assert_bool(drawn.has(family.personality)).override_failure_message(family.id).is_true()
		for shift: TraitShift in family.shifts:
			assert_bool(drawn.has(shift)).override_failure_message(family.id).is_true()
	var family: FamilyDef = RunDefaults.VILLAGE.families[0]
	var one: Array[Resource] = [family.personality]
	var bolder: Personality = family.personality.duplicate()
	var high: bool = bolder.bomb_aggression == Personality.Level.HIGH
	bolder.bomb_aggression = Personality.Level.LOW if high else Personality.Level.HIGH
	assert_str(ContentStamp.of([bolder], "1")).is_not_equal(ContentStamp.of(one, "1"))


func test_the_stamp_reads_a_definitions_plain_values_and_the_version() -> void:
	var cadre: ModifierDef = RunPools.STORE_CADRES.cadres[0]
	var same: ModifierDef = cadre.duplicate()
	var one: Array[Resource] = [cadre]
	assert_str(ContentStamp.of([same], "1")).is_equal(ContentStamp.of(one, "1"))
	assert_str(ContentStamp.of(one, "2")).is_not_equal(ContentStamp.of(one, "1"))
	var dearer: ModifierDef = cadre.duplicate()
	dearer.cost += 1
	assert_str(ContentStamp.of([dearer], "1")).is_not_equal(ContentStamp.of(one, "1"))
	var tuned: ModifierDef = cadre.duplicate()
	tuned.parameters = cadre.parameters.duplicate()
	tuned.parameters["a number the test adds"] = 1
	assert_str(ContentStamp.of([tuned], "1")).is_not_equal(ContentStamp.of(one, "1"))
	var later: ModifierDef = cadre.duplicate()
	later.unlock_tier += 1
	assert_str(ContentStamp.of([later], "1")).is_not_equal(ContentStamp.of(one, "1"))
	# One more definition in a pool is other content, as the second wave was.
	var two: Array[Resource] = [cadre, RunPools.STORE_CADRES.cadres[1]]
	assert_str(ContentStamp.of(two, "1")).is_not_equal(ContentStamp.of(one, "1"))
	# The same on every launch: nothing in it names where a Resource sits in memory.
	assert_str(ContentStamp.of(ContentStamp.drawn(), "1")).is_equal(
		ContentStamp.of(ContentStamp.drawn(), "1")
	)
	assert_bool(ContentStamp.current().contains("Object")).is_false()
