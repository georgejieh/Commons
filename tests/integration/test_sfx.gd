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
