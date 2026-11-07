class_name VoiceScript
extends RefCounted
## Works out how a villager says a line (P3B.13), in the way of Animalese-style babble:
## each letter plays its own sound as it types out. Spaces and punctuation pause. Each
## word steps its own pitch, the sentence drifts down, and only the last word carries
## the ending: questions rise, statements fall, exclamations come louder and faster,
## and "..." trails off. Digits are spelled out. Pure and deterministic: the same line
## in the same voice always gives the same plan, with no random stream.

const DEFAULT: VoiceTiming = preload("res://data/ui/voice_timing.tres")
const DIGITS: Array[String] = [
	"zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"
]
const SLOGAN: String = "slogan"
const TRAIL: String = "..."
## Sentence endings, by the index _sentences gives them.
const ENDINGS: Array[String] = [".", "?", "!", TRAIL]
## Endings that stay inside their sentence.
const STOPS: Array[String] = [".", "?", "!"]
## The span of a hash used as a fraction from 0 to 1.
const HASH_SPAN: int = 0xFFFF


## The plan for text in this voice. Dread runs 0 to 1, from the dread layers' weights.
static func plan(
	text: String,
	mood: String,
	voice: VoiceProfile,
	dread: float = 0.0,
	timing: VoiceTiming = DEFAULT,
) -> VoicePlan:
	var result: VoicePlan = VoicePlan.new()
	result.reveal.resize(text.length())
	result.reveal.fill(-1.0)
	var chars: PackedStringArray = PackedStringArray()
	var sources: PackedInt32Array = PackedInt32Array()
	_spoken(text, chars, sources)
	var shape: Vector4 = timing.moods[mood] if timing.moods.has(mood) else timing.moods[""]
	var flat: bool = mood == SLOGAN
	var clock: float = 0.0
	for sentence: Vector3i in _sentences(chars):
		var ending: String = ENDINGS[sentence.z]
		var drive: Vector2 = timing.ending_drive[ending]
		var rate: float = voice.pace * shape.y * drive.y * timing.letters_per_syllable
		var letter: float = 1.0 / maxf(0.1, rate * (1.0 - timing.dread_slow * dread))
		var line: Vector3 = Vector3(clock, letter, drive.x * shape.z)
		clock = _speak_sentence(text, chars, sources, sentence, ending, line, flat, timing, result)
		if ending == TRAIL:
			clock += letter * timing.trail_pause
	_shape_pitches(result, shape, flat, dread, timing)
	_fill_reveal(result.reveal)
	result.length = clock
	return result


## The line as spoken characters, lower case, with digits spelled out, and the index
## in text that each came from.
static func _spoken(text: String, chars: PackedStringArray, sources: PackedInt32Array) -> void:
	for index: int in text.length():
		var glyph: String = text[index].to_lower()
		var spelled: String = DIGITS[int(glyph)] if glyph >= "0" and glyph <= "9" else glyph
		for part: int in spelled.length():
			chars.append(spelled[part])
			sources.append(index)


## Each sentence as (first char, end char, ending index into . ? ! ...). The ending
## "..." is left out of the sentence; the others stay in, to pause.
static func _sentences(chars: PackedStringArray) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	var start: int = 0
	var index: int = 0
	while index < chars.size():
		if chars[index] == "." and index + 2 < chars.size():
			if chars[index + 1] == "." and chars[index + 2] == ".":
				result.append(Vector3i(start, index, 3))
				index += 3
				start = index
				continue
		var ending: int = STOPS.find(chars[index])
		index += 1
		if ending >= 0:
			result.append(Vector3i(start, index, ending))
			start = index
	if start < chars.size() and not "".join(chars.slice(start)).strip_edges().is_empty():
		result.append(Vector3i(start, chars.size(), 0))
	return result


## Times one sentence's letters and pauses into result, starting at line.x, with
## line.y seconds per letter and line.z loudness. Returns the clock after it. Pitch
## here is the bend before the mood's range; _shape_pitches finishes it.
static func _speak_sentence(
	text: String,
	chars: PackedStringArray,
	sources: PackedInt32Array,
	sentence: Vector3i,
	ending: String,
	line: Vector3,
	flat: bool,
	timing: VoiceTiming,
	result: VoicePlan,
) -> float:
	var words: Array[PackedInt32Array] = _words(chars, sentence, timing)
	var last: Vector2 = timing.endings[ending]
	var clock: float = line.x
	for word_index: int in words.size():
		var word: PackedInt32Array = words[word_index]
		var span: float = maxf(1.0, words.size() - 1)
		var drift: float = 1.0 + timing.declination * (0.5 - word_index / span)
		var spelling: String = _spelling(chars, word)
		var accent: float = _accent(spelling, timing)
		var letter_count: int = 0
		for entry: int in word:
			if chars[entry] in timing.pauses:
				result.reveal[sources[entry]] = clock
				clock += line.y * timing.pauses[chars[entry]]
				continue
			var bend: float = drift * (1.0 + accent)
			if word_index == words.size() - 1:
				var along: float = letter_count / maxf(1.0, spelling.length() - 1)
				bend = drift * lerpf(last.x, last.y, along)
			if flat:
				bend = 1.0
			if result.reveal[sources[entry]] < 0.0:
				result.reveal[sources[entry]] = clock
			result.letters.append(chars[entry])
			result.times.append(clock)
			result.pitches.append(bend * (1.0 + _wobble(text, result.letters.size(), timing)))
			result.volumes_db.append(linear_to_db(line.z))
			clock += line.y
			letter_count += 1
	return clock


## A sentence's words: each word's letter entries followed by the pauses after it.
static func _words(
	chars: PackedStringArray, sentence: Vector3i, timing: VoiceTiming
) -> Array[PackedInt32Array]:
	var words: Array[PackedInt32Array] = []
	var open: bool = false
	for entry: int in range(sentence.x, sentence.y):
		var glyph: String = chars[entry]
		var is_letter: bool = glyph >= "a" and glyph <= "z"
		if is_letter:
			if not open:
				words.append(PackedInt32Array())
				open = true
			words[-1].append(entry)
		elif glyph in timing.pauses:
			open = false
			if not words.is_empty():
				words[-1].append(entry)
	return words


static func _spelling(chars: PackedStringArray, word: PackedInt32Array) -> String:
	var spelling: String = ""
	for entry: int in word:
		if chars[entry] >= "a" and chars[entry] <= "z":
			spelling += chars[entry]
	return spelling


## A fixed pitch step for a word, so the same word always sounds the same.
static func _accent(word: String, timing: VoiceTiming) -> float:
	var long: bool = word.length() >= timing.long_word
	var span: Vector2 = timing.long_accent if long else timing.short_accent
	return lerpf(span.x, span.y, float(word.hash() & HASH_SPAN) / HASH_SPAN)


static func _wobble(text: String, index: int, timing: VoiceTiming) -> float:
	var unit: float = float(("%s#%d" % [text, index]).hash() & HASH_SPAN) / HASH_SPAN
	return timing.wobble * (unit * 2.0 - 1.0)


## Turns each bend into a pitch scale through the mood's range and overall pitch, with
## dread narrowing the range and quieting the voice.
static func _shape_pitches(
	result: VoicePlan, shape: Vector4, flat: bool, dread: float, timing: VoiceTiming
) -> void:
	var span: float = shape.x * (1.0 - timing.dread_narrow * dread)
	var quiet: float = linear_to_db(maxf(0.01, 1.0 - timing.dread_quiet * dread))
	for index: int in result.pitches.size():
		var bend: float = 1.0 if flat else result.pitches[index]
		result.pitches[index] = shape.w * (1.0 + (bend - 1.0) * span)
		result.volumes_db[index] += quiet


## Characters with no time of their own show with the one before them.
static func _fill_reveal(reveal: PackedFloat32Array) -> void:
	var last: float = 0.0
	for index: int in reveal.size():
		last = maxf(last, reveal[index])
		reveal[index] = last
