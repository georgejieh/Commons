extends GdUnitTestSuite
## Villager voices (P3B.13): one letter sound per letter as the line types out, the
## same line always gives the same sounds, and a sentence's ending shapes only its
## last word, so questions, statements, exclamations and trailing lines differ.

const WANG: VoiceProfile = preload("res://data/ui/voices/wang.tres")
const ZHAO: VoiceProfile = preload("res://data/ui/voices/zhao.tres")


## The last word's pitch at its end over its start, its last letter's volume, and the
## pitch its first letter starts at.
func _ending(text: String, last_word: int) -> Vector3:
	var plan: VoicePlan = VoiceScript.plan(text, "", ZHAO)
	var count: int = plan.pitches.size()
	var rise: float = plan.pitches[count - 1] / plan.pitches[count - last_word]
	return Vector3(rise, plan.volumes_db[count - 1], plan.pitches[count - last_word])


func test_the_same_line_always_gives_the_same_sounds() -> void:
	var first: VoicePlan = VoiceScript.plan("Who dealt this?", "sour", WANG)
	var second: VoicePlan = VoiceScript.plan("Who dealt this?", "sour", WANG)
	assert_array(Array(first.letters)).is_equal(Array(second.letters))
	assert_array(Array(first.times)).is_equal(Array(second.times))
	assert_array(Array(first.pitches)).is_equal(Array(second.pitches))
	assert_array(Array(first.reveal)).is_equal(Array(second.reveal))


func test_each_letter_plays_once_and_digits_are_spelled_out() -> void:
	var plan: VoicePlan = VoiceScript.plan("Down to 2.", "", WANG)
	assert_str("".join(plan.letters)).is_equal("downtotwo")
	assert_int(plan.reveal.size()).is_equal("Down to 2.".length())
	for index: int in range(1, plan.reveal.size()):
		assert_float(plan.reveal[index]).is_greater_equal(plan.reveal[index - 1])
	assert_float(plan.reveal[-1]).is_less_equal(plan.length)


func test_punctuation_pauses_longer_than_a_space() -> void:
	var spaced: VoicePlan = VoiceScript.plan("ab cd", "", WANG)
	var stopped: VoicePlan = VoiceScript.plan("ab. cd", "", WANG)
	var space_gap: float = spaced.times[2] - spaced.times[1]
	var stop_gap: float = stopped.times[2] - stopped.times[1]
	assert_float(stop_gap).is_greater(space_gap * 2.0)


func test_questions_statements_exclamations_and_trailing_lines_differ() -> void:
	var question: Vector3 = _ending("Who dealt this?", 4)
	var statement: Vector3 = _ending("Who dealt this.", 4)
	var exclaim: Vector3 = _ending("Who dealt this!", 4)
	var trail: Vector3 = _ending("Who dealt this...", 4)
	var rises: Array[float] = [question.x, statement.x, exclaim.x, trail.x]
	print("last-word rise: ? %.2f  . %.2f  ! %.2f  ... %.2f" % rises)
	assert_float(question.x).is_greater(1.2)
	assert_float(statement.x).is_less(0.95)
	assert_float(trail.x).is_less(statement.x - 0.1)
	assert_float(exclaim.z).is_greater(statement.z * 1.1)
	assert_float(exclaim.y).is_greater(statement.y + 1.0)
	var fast: VoicePlan = VoiceScript.plan("Who dealt this!", "", ZHAO)
	var plain: VoicePlan = VoiceScript.plan("Who dealt this.", "", ZHAO)
	assert_float(fast.times[1] - fast.times[0]).is_less(plain.times[1] - plain.times[0])
	var trailing: VoicePlan = VoiceScript.plan("Who dealt this...", "", ZHAO)
	assert_float(trailing.length - trailing.times[-1]).is_greater(plain.length - plain.times[-1])


func test_a_long_question_stays_level_until_its_last_word() -> void:
	var line: String = "You going to play that, or hold it till the thaw?"
	var plan: VoicePlan = VoiceScript.plan(line, "", ZHAO)
	var body: PackedFloat32Array = plan.pitches.slice(0, plan.pitches.size() - 4)
	var distinct: Dictionary[int, bool] = {}
	for pitch: float in body:
		assert_float(pitch).is_between(0.85, 1.2)
		distinct[roundi(pitch * 100.0)] = true
	assert_int(distinct.size()).is_greater(5)
	assert_float(plan.pitches[-1]).is_greater(body[0] * 1.15)


func test_slogans_speak_flat() -> void:
	var plan: VoicePlan = VoiceScript.plan("Every household brings one sack!", "slogan", WANG)
	for pitch: float in plan.pitches:
		assert_float(pitch).is_equal_approx(plan.pitches[0], 0.0001)


func test_dread_slows_narrows_and_quiets_the_voice() -> void:
	var line: String = "You going to play that, or hold it till the thaw?"
	var clean: VoicePlan = VoiceScript.plan(line, "", ZHAO, 0.0)
	var dread: VoicePlan = VoiceScript.plan(line, "", ZHAO, 1.0)
	assert_float(dread.length).is_greater(clean.length * 1.3)
	assert_float(_range(dread.pitches)).is_less(_range(clean.pitches) * 0.6)
	assert_float(dread.volumes_db[0]).is_less(clean.volumes_db[0] - 3.0)


func _range(pitches: PackedFloat32Array) -> float:
	var low: float = pitches[0]
	var high: float = pitches[0]
	for pitch: float in pitches:
		low = minf(low, pitch)
		high = maxf(high, pitch)
	return high - low
