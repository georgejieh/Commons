extends GdUnitTestSuite
## The ambience follows the board: every board state resolves to beds whose loops
## load, the clean board holds only the room and its chatter, beds crossfade to their
## targets, dip under hero effects, the crowd hushes when the player plays, and the beds
## sit on their own bus under Effects, keyed down by voices.

const SCORE: AmbienceScore = preload("res://data/audio/ambience_score.tres")
const CONFIG: HorrorConfig = preload("res://data/horror/horror_config.tres")
## A frame, for stepping fades.
const FRAME: float = 0.05
## Beds each board state must sound, and beds it must leave silent.
const HEARD: Dictionary[String, Array] = {
	"both_low": ["room", "chatter"],
	"famine_mid": ["room", "chatter", "wind"],
	"famine_high": ["room", "wind", "drone"],
	"denunciation_mid": ["room", "chatter", "rustle"],
	"denunciation_high": ["room", "chatter", "rustle", "whispers", "clock"],
	"both_high": ["room", "drone", "whispers", "clock", "crowd"],
	"landlord": ["hollow", "chatter"],
}
const UNHEARD: Dictionary[String, Array] = {
	"both_low": ["hollow", "wind", "drone", "rustle", "whispers", "clock", "crowd"],
	"famine_mid": ["drone", "whispers", "clock", "crowd"],
	"famine_high": ["chatter", "whispers", "clock", "crowd"],
	"denunciation_mid": ["drone", "wind", "whispers", "clock", "crowd"],
	"denunciation_high": ["drone", "crowd"],
	"both_high": ["chatter", "hollow"],
	"landlord": ["room", "drone", "crowd"],
}

var _ambience: AmbiencePlayer


func before_test() -> void:
	_ambience = auto_free(AmbiencePlayer.new())
	add_child(_ambience)
	# The test steps the fades itself.
	_ambience.set_process(false)


func after_test() -> void:
	Settings.set_value("horror_intensity", SettingsStore.DEFAULTS.get("horror_intensity"))


func test_every_bed_is_a_loop_that_loads() -> void:
	assert_int(SCORE.beds.size()).is_equal(9)
	for bed: AmbienceBed in SCORE.beds:
		var wav: AudioStreamWAV = bed.stream as AudioStreamWAV
		assert_object(wav).override_failure_message(bed.id).is_not_null()
		assert_int(wav.loop_mode).override_failure_message(bed.id).is_equal(
			AudioStreamWAV.LOOP_FORWARD
		)
		assert_int(wav.loop_begin).is_equal(0)
		assert_float(wav.get_length()).override_failure_message(bed.id).is_greater(5.0)
		assert_bool(wav.stereo).is_false()


func test_every_board_state_resolves_to_its_mix() -> void:
	for state: String in BoardState.BOARD_STATES:
		_settle_on(state, 1.0)
		for bed_id: String in HEARD[state]:
			(
				assert_float(_ambience.bed_level(bed_id))
				. override_failure_message("%s should sound in %s" % [bed_id, state])
				. is_greater(0.25)
			)
		for bed_id: String in UNHEARD[state]:
			(
				assert_float(_ambience.bed_level(bed_id))
				. override_failure_message("%s should be silent in %s" % [bed_id, state])
				. is_equal(0.0)
			)


func test_a_fresh_player_is_silent_as_on_the_title() -> void:
	_step(SCORE.fade_seconds + 1.0)
	for index: int in SCORE.beds.size():
		assert_float(_ambience.bed_level(SCORE.beds[index].id)).is_equal(0.0)
		assert_bool(_player(index).playing).is_false()


func test_weights_at_zero_bring_in_no_dread_bed() -> void:
	var board: BoardState = BoardState.new(CONFIG)
	_ambience.follow(board, CONFIG.layers, 1.0)
	_step(SCORE.fade_seconds + 0.1)
	for bed: AmbienceBed in SCORE.beds:
		var expected: float = 1.0 if bed.on_clean_board else 0.0
		assert_float(_ambience.bed_gain(bed.id)).override_failure_message(bed.id).is_equal(expected)


func test_horror_intensity_zero_keeps_every_dread_bed_silent() -> void:
	for state: String in ["famine_high", "denunciation_high", "both_high", "landlord"]:
		_settle_on(state, 0.0)
		for bed: AmbienceBed in SCORE.beds:
			var expected: float = 1.0 if bed.on_clean_board else 0.0
			(
				assert_float(_ambience.bed_gain(bed.id))
				. override_failure_message("%s in %s" % [bed.id, state])
				. is_equal(expected)
			)


func test_leaving_the_table_fades_everything_out_and_pauses_it() -> void:
	_settle_on("both_high", 1.0)
	_ambience.silence()
	_step(SCORE.fade_seconds + 0.1)
	for index: int in SCORE.beds.size():
		assert_float(_ambience.bed_level(SCORE.beds[index].id)).is_equal(0.0)
		assert_bool(_player(index).playing and not _player(index).stream_paused).is_false()


func test_the_crossfade_is_slow_and_reaches_its_target() -> void:
	var board: BoardState = BoardState.new(CONFIG)
	board.set_inputs(90, 90, false, 0)
	board.settle()
	_ambience.follow(board, CONFIG.layers, 1.0)
	var target: float = AmbiencePlayer.gain_for(SCORE.bed("crowd"), board, CONFIG.layers, 1.0)
	assert_float(target).is_greater(0.5)
	var last: float = 0.0
	var elapsed: float = 0.0
	while elapsed < SCORE.fade_seconds * target - FRAME:
		_step(FRAME)
		elapsed += FRAME
		var gain: float = _ambience.bed_gain("crowd")
		assert_float(gain).is_greater(last)
		assert_float(gain).is_less(target)
		last = gain
	_step(FRAME * 2.0)
	assert_float(_ambience.bed_gain("crowd")).is_equal_approx(target, 0.0001)


func test_hero_effects_dip_every_bed_and_it_comes_back() -> void:
	_settle_on("both_low", 1.0)
	var full: float = _ambience.bed_level("room")
	_ambience.duck_for(AudioEvents.MOTION_HOVER)
	_step(SCORE.duck_attack_seconds)
	assert_float(_ambience.bed_level("room")).is_equal(full)
	_ambience.duck_for(AudioEvents.BOMB_NAME)
	_step(SCORE.duck_attack_seconds + FRAME)
	assert_float(_ambience.bed_level("room")).is_equal_approx(
		full * db_to_linear(SCORE.duck_db), 0.001
	)
	_step(SCORE.duck_hold_seconds + SCORE.duck_release_seconds + FRAME)
	assert_float(_ambience.bed_level("room")).is_equal_approx(full, 0.0001)


func test_the_crowd_hushes_when_the_player_plays_and_returns() -> void:
	_settle_on("both_high", 1.0)
	var crowd: float = _ambience.bed_level("crowd")
	var drone: float = _ambience.bed_level("drone")
	_ambience.hush()
	_step(SCORE.hush_attack_seconds + FRAME)
	assert_float(_ambience.bed_level("crowd")).is_equal(0.0)
	assert_float(_ambience.bed_level("drone")).is_equal(drone)
	_step(SCORE.hush_hold_seconds + SCORE.hush_release_seconds + FRAME)
	assert_float(_ambience.bed_level("crowd")).is_equal_approx(crowd, 0.0001)


func test_only_the_players_own_play_hushes_the_crowd() -> void:
	var mine: RunEvent = RunEvent.wrap(RoundEvent.new(RoundEvent.Type.PLAYED, RunLoop.PLAYER))
	var theirs: RunEvent = RunEvent.wrap(RoundEvent.new(RoundEvent.Type.PLAYED, 1))
	var passed: RunEvent = RunEvent.wrap(RoundEvent.new(RoundEvent.Type.PASSED, RunLoop.PLAYER))
	assert_bool(AudioEvents.played_by_player(mine)).is_true()
	assert_bool(AudioEvents.played_by_player(theirs)).is_false()
	assert_bool(AudioEvents.played_by_player(passed)).is_false()


func test_the_table_moves_the_beds_and_leaving_it_silences_them() -> void:
	var intensity: Variant = Settings.value("horror_intensity")
	Settings.set_value("horror_intensity", 1.0)
	var layer: HorrorLayer = HorrorLayer.new()
	layer.input = "struggle"
	layer.audio_stems = ["crowd"]
	var config: HorrorConfig = HorrorConfig.new()
	config.layers = [layer]
	var dread: DreadLayers = auto_free(DreadLayers.new())
	add_child(dread)
	dread.config = config
	var dressing: DreadDressing = auto_free(DreadDressing.new())
	add_child(dressing)
	var materials: Dictionary[String, ShaderMaterial] = {}
	var seats: Array[SeatPanel] = []
	dread.setup(materials, dressing, seats)
	dread.force(90, 90, false)
	Audio.ambience._process(SCORE.fade_seconds + 0.1)
	assert_float(Audio.ambience.bed_level("crowd")).is_equal(1.0)
	assert_float(Audio.ambience.bed_level("room")).is_equal(1.0)
	dread.clear()
	Audio.ambience._process(SCORE.fade_seconds + 0.1)
	assert_float(Audio.ambience.bed_level("crowd")).is_equal(0.0)
	assert_float(Audio.ambience.bed_level("room")).is_equal(0.0)
	Settings.set_value("horror_intensity", intensity)


func test_players_are_made_once() -> void:
	assert_int(_ambience.get_child_count()).is_equal(SCORE.beds.size())
	_settle_on("both_high", 1.0)
	_settle_on("landlord", 1.0)
	assert_int(_ambience.get_child_count()).is_equal(SCORE.beds.size())


func test_the_beds_play_on_their_bus_under_effects_and_dip_under_voices() -> void:
	var index: int = AudioServer.get_bus_index(AudioMixer.BUS_AMBIENCE)
	assert_int(index).is_not_equal(-1)
	assert_str(AudioServer.get_bus_send(index)).is_equal(AudioMixer.BUS_EFFECTS)
	var keyed: bool = false
	for effect: int in AudioServer.get_bus_effect_count(index):
		var duck: AudioEffectCompressor = (
			AudioServer.get_bus_effect(index, effect) as AudioEffectCompressor
		)
		keyed = keyed or (duck != null and duck.sidechain == AudioMixer.BUS_VOICE)
	assert_bool(keyed).is_true()
	for player: int in SCORE.beds.size():
		assert_str(_player(player).bus).is_equal(AudioMixer.BUS_AMBIENCE)


func _settle_on(state: String, intensity: float) -> void:
	var meters: Vector3 = BoardState.BOARD_STATES[state]
	var board: BoardState = BoardState.new(CONFIG)
	board.set_inputs(int(meters.x), int(meters.y), meters.z > 0.0, 0)
	board.settle()
	_ambience.follow(board, CONFIG.layers, intensity)
	_step(SCORE.fade_seconds + 0.1)


func _step(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		_ambience._process(minf(FRAME, left))
		left -= FRAME


func _player(index: int) -> AudioStreamPlayer:
	return _ambience.get_child(index) as AudioStreamPlayer
