extends GdUnitTestSuite
## The reading slip with as many readings as one play can have (ADR 0029): every reading
## and Cancel stay on screen and clear of the hand.

const SCREEN: Rect2 = Rect2(0, 0, 1920, 1080)


func _picker() -> ReadingPicker:
	var picker: ReadingPicker = auto_free(ReadingPicker.new())
	add_child(picker)
	return picker


## Sevens wild, and the lead 3 4 7 7 7 7: a Straight, a Pair Run, an Airplane and every
## Four with Two.
func _many() -> Array[Pattern]:
	var sevens: RuleSet = WildReference.rules([Ranks.SEVEN] as Array[int], false)
	return Readings.of(RankText.counts("347777"), sevens, Ranks.identity_map())


func test_a_play_with_many_readings_keeps_every_choice_on_screen() -> void:
	var readings: Array[Pattern] = _many()
	assert_int(readings.size()).is_greater(12)
	var picker: ReadingPicker = _picker()
	picker.open(readings)
	await await_millis(600)
	var room: Rect2 = Rect2(
		0, ReadingPicker.TOP - 1.0, SCREEN.size.x, ReadingPicker.BOTTOM - ReadingPicker.TOP + 2.0
	)
	assert_bool(room.encloses(picker.slip_rect())).is_true()
	for index: int in readings.size():
		var choice: Rect2 = picker.choice(index).get_global_rect()
		assert_bool(room.encloses(choice)).override_failure_message(str(index)).is_true()
		assert_float(choice.size.y).is_greater(20.0)
	assert_bool(room.encloses(picker.cancel_button().get_global_rect())).is_true()
	# A click lands on the choice drawn there, the last as well as the first.
	var chosen: Array[Pattern] = []
	picker.chosen.connect(func(reading: Pattern) -> void: chosen.append(reading))
	picker.choice(readings.size() - 1).pressed.emit()
	assert_bool(chosen[0].same_reading(readings[readings.size() - 1])).is_true()


func test_a_short_slip_is_drawn_full_size() -> void:
	var readings: Array[Pattern] = _many()
	readings.resize(2)
	var picker: ReadingPicker = _picker()
	picker.open(readings)
	await await_millis(600)
	assert_float(picker.slip_rect().size.x).is_equal_approx(ReadingPicker.WIDTH, 0.5)
	assert_float(picker.slip_rect().end.y).is_equal_approx(ReadingPicker.BOTTOM, 0.5)
