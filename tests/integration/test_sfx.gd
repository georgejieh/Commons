extends GdUnitTestSuite
## Sound effects (P3C.8): every sound in the bank answers an event the game names, has
## takes that load, and plays them round-robin; every button clicks.

const BANK: SfxBank = preload("res://data/audio/sfx_bank.tres")

var _effects: SfxPlayer


func before_test() -> void:
	_effects = auto_free(SfxPlayer.new())
	add_child(_effects)


func test_every_sound_answers_a_named_event() -> void:
	var names: Array[String] = []
	names.append_array(AudioEvents.RUN_NAMES.values())
	names.append_array(AudioEvents.ROUND_NAMES.values())
	names.append_array(AudioEvents.MOTION_NAMES)
	(
		names
		. append_array(
			[
				AudioEvents.BOMB_NAME,
				AudioEvents.ROCKET_NAME,
				AudioEvents.ROUND_WON,
				AudioEvents.ROUND_LOST,
				AudioEvents.METER_ROSE,
				AudioEvents.STORE_BUY,
				AudioMixer.CLICK,
			]
		)
	)
	for sound: SfxSound in BANK.sounds:
		assert_bool(names.has(sound.id)).override_failure_message(sound.id).is_true()


func test_the_table_events_all_have_sounds() -> void:
	for id: String in [
		"dealt",
		"card_played",
		"passed",
		"trick_won",
		AudioEvents.BOMB_NAME,
		AudioEvents.ROCKET_NAME,
		AudioEvents.ROUND_WON,
		AudioEvents.ROUND_LOST,
		AudioEvents.METER_ROSE,
		AudioEvents.STORE_BUY,
		AudioMixer.CLICK,
	]:
		var sound: SfxSound = BANK.sound(id)
		assert_object(sound).override_failure_message(id).is_not_null()
		if sound == null:
			continue
		assert_int(sound.streams.size()).override_failure_message(id).is_greater(0)
		for stream: AudioStream in sound.streams:
			assert_object(stream).override_failure_message(id).is_not_null()
			assert_float(stream.get_length()).override_failure_message(id).is_greater(0.0)


## Every scored play's beats and every motion's own sound have takes that load (P5.2a).
func test_every_motion_and_scoring_beat_has_a_sound() -> void:
	for id: String in AudioEvents.MOTION_NAMES:
		var sound: SfxSound = BANK.sound(id)
		assert_object(sound).override_failure_message(id).is_not_null()
		if sound == null:
			continue
		assert_int(sound.voices).override_failure_message(id).is_between(1, 4)
		for stream: AudioStream in sound.streams:
			assert_object(stream).override_failure_message(id).is_not_null()
			assert_float(stream.get_length()).override_failure_message(id).is_between(0.01, 0.7)


## A motion's sound fills only a silence: right after an event's own sound it keeps
## quiet, and once the moment has passed it plays.
func test_a_motion_sound_never_lands_on_an_events_own() -> void:
	Audio.last_filled = ""
	Audio.play("card_played")
	Audio.fill(AudioEvents.MOTION_STAMP)
	await await_millis(30)
	assert_str(Audio.last_filled).is_empty()
	# The moment has passed: set the last sound back rather than wait on the clock, so a
	# sound left playing by another suite cannot land inside the wait.
	Audio.set("_played_msec", Time.get_ticks_msec() - AudioMixer.FILL_GUARD_MSEC - 1)
	Audio.fill(AudioEvents.MOTION_STAMP)
	await await_millis(30)
	assert_str(Audio.last_filled).is_equal(AudioEvents.MOTION_STAMP)


func test_a_step_up_raises_the_pitch() -> void:
	assert_bool(_effects.play(AudioEvents.SCORE_CHIME, 7.0)).is_true()
	var player: AudioStreamPlayer = _effects.get_child(0)
	assert_float(player.pitch_scale).is_equal_approx(pow(2.0, 7.0 / 12.0), 0.001)


func test_takes_play_round_robin() -> void:
	var takes: int = BANK.sound("card_played").streams.size()
	assert_int(takes).is_greater(1)
	for step: int in takes + 1:
		assert_int(_effects.next_take("card_played")).is_equal(step % takes)
		assert_bool(_effects.play("card_played")).is_true()


func test_an_event_without_a_sound_is_silent() -> void:
	assert_bool(_effects.play("no_such_event")).is_false()
	assert_bool(_effects.play("set_started")).is_false()


func test_every_button_clicks() -> void:
	var button: Button = auto_free(Button.new())
	add_child(button)
	Audio.last_played = ""
	button.pressed.emit()
	assert_str(Audio.last_played).is_equal(AudioMixer.CLICK)


func test_a_button_clicks_once_after_reentering_the_tree() -> void:
	var button: Button = auto_free(Button.new())
	add_child(button)
	remove_child(button)
	add_child(button)
	assert_int(button.pressed.get_connections().size()).is_equal(1)


func test_master_has_a_limiter() -> void:
	var found: bool = false
	for effect: int in AudioServer.get_bus_effect_count(0):
		found = found or AudioServer.get_bus_effect(0, effect) is AudioEffectHardLimiter
	assert_bool(found).is_true()
