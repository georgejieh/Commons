extends GdUnitTestSuite
## The music follows the board (P3C.9): the cue comes from the Famine weight and the
## landlord seat, the dread layers thin stems by volume only, and a new cue waits for a
## bar line. Real music arrives from Suno; these tests use generated tones.

const SCORE: MusicScore = preload("res://data/audio/music_score.tres")
const CONFIG: HorrorConfig = preload("res://data/horror/horror_config.tres")
const RATE: int = 8000

var _music: MusicPlayer


func before_test() -> void:
	_music = auto_free(MusicPlayer.new())
	add_child(_music)


func test_the_cue_follows_famine_and_the_landlord_seat() -> void:
	assert_str(SCORE.cue_for(0.0, false)).is_equal(SCORE.village)
	assert_str(SCORE.cue_for(0.0, true)).is_equal(SCORE.landlord)
	assert_str(SCORE.cue_for(SCORE.famine_mid_at, true)).is_equal(SCORE.famine_mid)
	assert_str(SCORE.cue_for(1.0, false)).is_equal(SCORE.famine_high)
	for cue_id: String in [SCORE.village, SCORE.landlord, SCORE.famine_mid, SCORE.famine_high]:
		assert_object(SCORE.cue(cue_id)).is_not_null()


func test_layers_thin_only_the_stems_they_name() -> void:
	var weights: PackedFloat32Array = []
	weights.resize(CONFIG.layers.size())
	weights.fill(0.0)
	weights[0] = 0.75  # Famine
	assert_float(SCORE.stem_gain("percussion", CONFIG.layers, weights)).is_equal_approx(0.25, 0.001)
	assert_float(SCORE.stem_gain("harmony", CONFIG.layers, weights)).is_equal(1.0)


func test_a_new_cue_waits_for_the_next_bar_line() -> void:
	var cue: MusicCue = SCORE.cue(SCORE.village)
	var bar: float = cue.bar_seconds()
	assert_float(bar).is_equal_approx(60.0 / cue.bpm * cue.beats_per_bar, 0.0001)
	assert_float(MusicPlayer.seconds_to_bar(cue, 0.0)).is_equal(0.0)
	assert_float(MusicPlayer.seconds_to_bar(cue, bar * 0.25)).is_equal_approx(bar * 0.75, 0.001)
	assert_float(MusicPlayer.seconds_to_bar(cue, bar * 2.0 + 0.01)).is_equal(0.0)


func test_famine_fades_its_stems_by_volume_and_they_return() -> void:
	_music.request(SCORE.village)
	assert_str(_music.current_id()).is_equal(SCORE.village)
	var board: BoardState = BoardState.new(CONFIG)
	board.set_inputs(100, 0, false, 0)
	board.settle()
	_music.follow(board, CONFIG.layers, 1.0)
	_music._process(SCORE.fade_seconds + 0.1)
	assert_float(_music.stem_gain("percussion")).is_equal(0.0)
	assert_float(_music.stem_gain("harmony")).is_equal(1.0)
	board.set_inputs(0, 0, false, 0)
	board.settle()
	_music.follow(board, CONFIG.layers, 1.0)
	_music._process(SCORE.fade_seconds + 0.1)
	assert_float(_music.stem_gain("percussion")).is_equal(1.0)


func test_stems_share_one_synchronized_stream_and_fade_by_volume() -> void:
	var cue: MusicCue = MusicCue.new()
	cue.id = "test_tones"
	cue.stem_names = ["melody", "percussion"]
	cue.stems = [_tone(440.0), _tone(220.0)]
	var score_cues: Array[MusicCue] = SCORE.cues
	score_cues.append(cue)
	_music.request("test_tones")
	var player: AudioStreamPlayer = _music.get("_player")
	var mix: AudioStreamSynchronized = player.stream as AudioStreamSynchronized
	assert_object(mix).is_not_null()
	assert_int(mix.stream_count).is_equal(2)
	var board: BoardState = BoardState.new(CONFIG)
	board.set_inputs(100, 0, false, 0)
	board.settle()
	_music.follow(board, CONFIG.layers, 1.0)
	_music._process(SCORE.fade_seconds + 0.1)
	# Faded, not removed: the stem keeps its place in the stream at silent volume.
	assert_int(mix.stream_count).is_equal(2)
	assert_float(mix.get_sync_stream_volume(1)).is_equal(MusicPlayer.SILENT_DB)
	assert_float(mix.get_sync_stream_volume(0)).is_equal_approx(0.0, 0.001)
	score_cues.erase(cue)


func _tone(hertz: float) -> AudioStreamWAV:
	var data: PackedByteArray = []
	data.resize(RATE * 2)
	for index: int in RATE:
		var sample: int = int(sin(TAU * hertz * index / RATE) * 8000.0)
		data.encode_s16(index * 2, sample)
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = RATE
	return wav
