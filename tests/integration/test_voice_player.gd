extends GdUnitTestSuite
## The voice player (P3B.13): every family has a 26-letter bank, a line plays one sound
## per letter and then ends, stopping plays nothing more, the seat's text types out in
## step and skipping it stops the voice, and playback stays inside the frame budget.

const VILLAGE: VillageBook = preload("res://data/villagers/village.tres")
const ZHAO: VoiceProfile = preload("res://data/ui/voices/zhao.tres")
const LINE: String = "You going to play that, or hold it till the thaw?"
const FRAME: float = 1.0 / 60.0
## Voice work per frame, two seats talking, in microseconds.
const BUDGET_USEC: float = 100.0

var _voice: VoicePlayer


func before_test() -> void:
	_voice = auto_free(VoicePlayer.new())
	add_child(_voice)
	_voice.set_process(false)


func test_every_family_and_youth_has_a_full_letter_bank() -> void:
	for family: FamilyDef in VILLAGE.families + VILLAGE.youth_templates:
		assert_object(family.voice).is_not_null()
		for index: int in VoicePlayer.LETTERS.length():
			var path: String = VoicePlayer.BANK_PATH % [family.id, VoicePlayer.LETTERS[index]]
			assert_bool(ResourceLoader.exists(path)).override_failure_message(path).is_true()


func test_a_line_plays_one_sound_per_letter_and_ends() -> void:
	var plan: VoicePlan = _voice.speak(1, LINE, "", ZHAO, "zhao")
	var steps: int = ceili(plan.length / FRAME) + 2
	for step: int in steps:
		_voice.advance(FRAME)
	assert_int(_voice.letters_played(1)).is_equal(plan.letters.size())
	assert_bool(_voice.is_speaking(1)).is_false()


func test_stopping_plays_nothing_more() -> void:
	var plan: VoicePlan = _voice.speak(2, LINE, "", ZHAO, "zhao")
	_voice.advance(plan.length / 3.0)
	var said: int = _voice.letters_played(2)
	assert_int(said).is_between(1, plan.letters.size() - 1)
	_voice.stop(2)
	_voice.advance(plan.length)
	assert_int(_voice.letters_played(2)).is_equal(said)


func test_the_text_types_out_in_step_and_skipping_stops_the_voice() -> void:
	var panel: SeatPanel = auto_free(SeatPanel.new())
	add_child(panel)
	panel.seat = 1
	panel.speech_skipped.connect(_voice.stop)
	var plan: VoicePlan = _voice.speak(1, LINE, "", ZHAO, "zhao")
	panel.say(LINE, "", plan.reveal)
	assert_int(panel.shown_characters()).is_equal(0)
	panel._process(plan.length / 2.0)
	assert_int(panel.shown_characters()).is_between(1, LINE.length() - 1)
	assert_bool(panel.skip_speech()).is_true()
	assert_int(panel.shown_characters()).is_equal(LINE.length())
	assert_bool(_voice.is_speaking(1)).is_false()
	assert_bool(panel.skip_speech()).is_false()
	assert_str(panel.speech()).is_equal(LINE)


func test_a_line_with_no_voice_shows_at_once() -> void:
	var panel: SeatPanel = auto_free(SeatPanel.new())
	add_child(panel)
	panel.say("Pass.")
	assert_int(panel.shown_characters()).is_equal(5)
	assert_bool(panel.is_typing()).is_false()


func test_playback_stays_inside_the_frame_budget() -> void:
	var frames: int = 0
	var spent: int = 0
	for repeat: int in 20:
		_voice.speak(1, LINE, "", ZHAO, "zhao")
		_voice.speak(2, LINE, "eager", ZHAO, "zhao")
		while _voice.is_speaking(1) or _voice.is_speaking(2):
			var start: int = Time.get_ticks_usec()
			_voice.advance(FRAME)
			spent += Time.get_ticks_usec() - start
			frames += 1
	var mean: float = float(spent) / frames
	print("voice: %.1f usec per frame over %d frames" % [mean, frames])
	assert_float(mean).is_less(BUDGET_USEC)
