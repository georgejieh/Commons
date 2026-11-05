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


func test_bars_count_from_the_first_downbeat() -> void:
	var cue: MusicCue = MusicCue.new()
	cue.bpm = 120.0
	cue.downbeat = 0.4
	var bar: float = cue.bar_seconds()
	assert_float(bar).is_equal_approx(2.0, 0.0001)
	assert_int(MusicPlayer.bar_at(cue, 0.2)).is_equal(-1)
	assert_int(MusicPlayer.bar_at(cue, 0.4)).is_equal(0)
	assert_int(MusicPlayer.bar_at(cue, 2.39)).is_equal(0)
	assert_int(MusicPlayer.bar_at(cue, 2.41)).is_equal(1)


func test_a_waiting_cue_starts_when_playback_crosses_a_bar_even_between_frames() -> void:
	var village: MusicCue = _tone_cue("tone_village", ["melody", "percussion"])
	var famine: MusicCue = _tone_cue("tone_famine", ["melody"])
	_music.request("tone_village")
	_music.request("tone_famine")
	assert_str(_music.pending_id()).is_equal("tone_famine")
	var bar: float = village.bar_seconds()
	# Frames either side of a bar line, neither within any tolerance of it.
	_music.call("_check_bar", bar * 0.98)
	assert_str(_music.current_id()).is_equal("tone_village")
	_music.call("_check_bar", bar * 1.02)
	assert_str(_music.current_id()).is_equal("tone_famine")
	_remove(village)
	_remove(famine)


func test_asking_for_the_playing_cue_cancels_a_waiting_change() -> void:
	var village: MusicCue = _tone_cue("tone_village", ["melody"])
	var landlord: MusicCue = _tone_cue("tone_landlord", ["melody"])
	_music.request("tone_landlord")
	_music.request("tone_village")
	_music.request("tone_landlord")
	assert_str(_music.pending_id()).is_empty()
	_music.call("_check_bar", 0.0)
	_music.call("_check_bar", landlord.bar_seconds() * 1.5)
	assert_str(_music.current_id()).is_equal("tone_landlord")
	_remove(village)
	_remove(landlord)


func test_a_held_down_stem_stays_down_across_a_cue_change() -> void:
	var village: MusicCue = _tone_cue("tone_village", ["melody", "percussion"])
	var famine: MusicCue = _tone_cue("tone_famine", ["melody", "harmony"])
	_music.request("tone_village")
	var board: BoardState = BoardState.new(CONFIG)
	board.set_inputs(0, 100, false, 0)
	board.settle()
	_music.follow(board, CONFIG.layers, 1.0)
	_music._process(SCORE.fade_seconds + 0.1)
	assert_float(_music.stem_gain("melody")).is_equal(0.0)
	_music.request("tone_famine")
	_music.call("_check_bar", 0.0)
	_music.call("_check_bar", village.bar_seconds() * 1.1)
	assert_str(_music.current_id()).is_equal("tone_famine")
	assert_float(_music.stem_gain("melody")).is_equal(0.0)
	assert_float(_music.stem_gain("harmony")).is_equal(1.0)
	_remove(village)
	_remove(famine)


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
	var cue: MusicCue = _tone_cue("test_tones", ["melody", "percussion"])
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
	_remove(cue)


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


## A cue of generated tones, one per stem, added to the shipped score for one test.
func _tone_cue(cue_id: String, names: Array[String]) -> MusicCue:
	var cue: MusicCue = MusicCue.new()
	cue.id = cue_id
	cue.stem_names = names
	for index: int in names.size():
		cue.stems.append(_tone(220.0 * (index + 1)))
	var cues: Array[MusicCue] = SCORE.cues
	cues.append(cue)
	return cue


func _remove(cue: MusicCue) -> void:
	var cues: Array[MusicCue] = SCORE.cues
	cues.erase(cue)
