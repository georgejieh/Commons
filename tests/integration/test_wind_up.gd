extends GdUnitTestSuite
## The beat before a villager's play: the table marks the seat, and its cards
## leave a moment later, so a play the player did not choose can be followed. Their own
## play answers at once.


## A villager's play is announced a beat before it happens, and the player's own is not:
## they chose it, and it answers at once.
func test_a_villagers_play_is_wound_up_and_the_players_own_is_not() -> void:
	var player: EventPlayer = auto_free(EventPlayer.new())
	add_child(player)
	player.step = 0.05
	player.wind = 0.3
	var seen: Array[String] = []
	player.winding.connect(func(event: RunEvent) -> void: seen.append("wind %d" % event.seat))
	player.played.connect(func(event: RunEvent) -> void: seen.append("play %d" % event.seat))
	player.push(RunEvent.wrap(RoundEvent.new(RoundEvent.Type.PLAYED, 0)))
	await await_millis(60)
	assert_array(seen).is_equal(["play 0"])
	seen.clear()
	await await_millis(100)
	player.push(RunEvent.wrap(RoundEvent.new(RoundEvent.Type.PLAYED, 2)))
	await await_millis(120)
	assert_array(seen).is_equal(["wind 2"])
	assert_bool(player.is_idle()).is_false()
	await await_millis(350)
	assert_array(seen).is_equal(["wind 2", "play 2"])
	# A pass is tagged on its seat and needs no wind-up; nor does anything with wind off.
	seen.clear()
	player.push(RunEvent.wrap(RoundEvent.new(RoundEvent.Type.PASSED, 1)))
	await await_millis(150)
	assert_array(seen).is_equal(["play 1"])
	seen.clear()
	player.wind = 0.0
	player.push(RunEvent.wrap(RoundEvent.new(RoundEvent.Type.PLAYED, 1)))
	await await_millis(150)
	assert_array(seen).is_equal(["play 1"])
	# Skipping plays everything at once, with nothing announced.
	seen.clear()
	player.wind = 0.3
	player.push(RunEvent.wrap(RoundEvent.new(RoundEvent.Type.PLAYED, 1)))
	player.flush()
	assert_array(seen).is_equal(["play 1"])


## The seat swells for the wind-up and is back at rest once the cards have flown, and
## reduced motion leaves it alone.
func test_a_wound_up_seat_swells_and_settles() -> void:
	var motion: TableMotion = auto_free(TableMotion.new())
	add_child(motion)
	var seat: Control = auto_free(Control.new())
	seat.size = Vector2(240, 300)
	add_child(seat)
	var presets: MotionPresets = UiMotion.PRESETS
	motion.wind_up(seat, presets.wind_up)
	await await_millis(int(presets.wind_up * 1000.0))
	assert_float(seat.scale.x).is_greater(1.0)
	assert_float(seat.scale.x).is_less_equal(presets.wind_scale + 0.001)
	assert_vector(seat.pivot_offset).is_equal(seat.size / 2.0)
	await await_millis(int(presets.fly_time * 1000.0) + 150)
	assert_vector(seat.scale).is_equal(Vector2.ONE)
	motion.set_still(true)
	motion.wind_up(seat, presets.wind_up)
	await await_millis(60)
	assert_vector(seat.scale).is_equal(Vector2.ONE)
