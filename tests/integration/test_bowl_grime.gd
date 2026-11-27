extends GdUnitTestSuite
## The dice bowl is never clean, and gets dirtier with corruption (ADR 0018).


func after_test() -> void:
	ArtStages.stage_override = -1


func test_nothing_is_clean_even_before_corruption() -> void:
	ArtStages.stage_override = 0
	assert_float(BowlGrime.wear()).is_equal_approx(BowlGrime.BASE_WEAR, 0.001)
	(
		assert_bool(BowlGrime.aged(DiceBowl.PORCELAIN, BowlGrime.wear()) == DiceBowl.PORCELAIN)
		. is_false()
	)


func test_wear_rises_with_every_stage() -> void:
	var last: float = 0.0
	for stage: int in BoardState.CORRUPTION_STAGES:
		ArtStages.stage_override = stage
		assert_float(BowlGrime.wear()).is_greater(last)
		last = BowlGrime.wear()
	assert_float(last).is_equal_approx(1.0, 0.001)


func test_the_one_looks_back_only_at_the_deep_stages() -> void:
	ArtStages.stage_override = BowlGrime.EYE_STAGE - 1
	assert_bool(BowlGrime.watching()).is_false()
	ArtStages.stage_override = BowlGrime.EYE_STAGE
	assert_bool(BowlGrime.watching()).is_true()


func test_the_bowl_draws_at_the_first_and_last_stage() -> void:
	for stage: int in [0, BoardState.CORRUPTION_STAGES - 1]:
		ArtStages.stage_override = stage
		var bowl: DiceBowl = auto_free(DiceBowl.new())
		add_child(bowl)
		bowl.size = Vector2(1920, 1080)
		bowl.center = Vector2(960, 540)
		var seats: Array[int] = [0, 1]
		var faces: Array[int] = [1, 4]
		var names: Array[String] = ["You", "Zhao"]
		var seconds: float = bowl.roll(seats, faces, 1, names)
		await await_millis(int(seconds * 1000.0) + 150)
		assert_bool(bowl.is_showing()).is_true()
		assert_array(bowl.faces()).is_equal(faces)
