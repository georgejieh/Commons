class_name TableSpeech
extends RefCounted
## Turns run events into what villagers say at the table. Lines come from the SpeechBook by
## event. Each seat cycles through a salt, so the same events in the same order always give
## the same lines, with no global random. One villager talks at a time: a line for another
## seat waits in a short queue until the one typing out ends. A seat's newer line for the
## same event replaces its older one, and when the queue overflows, idle chatter goes
## before announcements. Skipping shows every waiting line at once, silently. In a run that
## began with an entry in the family's file (ADR 0022), a villager's line for one moment is
## now and then about the work team's visit instead, drawn on the table's own seeded
## stream; a run with no entry draws nothing. On a corrupted profile under Denunciation,
## ordinary lines turn by degrees into the speech book's slogans, the share from the
## dread's slogan weight on a fixed sequence; at the last stages the other villager says
## the same slogan at once.

## A villager said a line, for tests: the table voices the line itself, and tests count
## what was said here.
signal spoke(seat: int, event: String, line: SpeechLine)

const BOOK: SpeechBook = preload("res://data/ui/speech_book.tres")
const VISIT: WorkTeamTalk = preload("res://data/ui/work_team_talk.tres")
## Spreads the seats' salts so two villagers rarely say the same line together.
const SEAT_SALT: int = 7
## The most lines that wait at once, and the events that are only chatter.
const QUEUE_MAX: int = 3
const CHATTER: Array[String] = ["pass", "call", "no_call"]
## Steps each seat's count of lines along an even spread from 0 to 1, so the share of
## slogans comes out the same over any run of lines; the golden ratio's fraction.
const SPREAD: float = 0.618034

## True while the table skips ahead: every line shows at once, with no voice.
var hurrying: bool = false
## The board's dread, whose slogan weight turns lines into slogans; none says none.
var dread: DreadLayers = null

var _seats: Dictionary[int, SeatPanel] = {}
var _said: Dictionary[int, int] = {}
var _landlord: int = Seats.NONE
## Each seated family's own lines, said alongside the shared book's.
var _books: Dictionary[int, SpeechBook] = {}
## Each seat's voice and letter bank. A seat with none speaks silently.
var _voices: Dictionary[int, VoiceProfile] = {}
var _voice_banks: Dictionary[int, String] = {}
## Lines waiting for the table to fall quiet, oldest first: seat, event and fields.
var _waiting: Array[Dictionary] = []
## The draws for the work team's lines, or null in a run with no entry in the file.
var _visit: RandomStream = null


func setup(seats: Dictionary[int, SeatPanel], app: DemoApp = null) -> void:
	_seats = seats
	_waiting.clear()
	for seat: int in seats:
		if not seats[seat].speech_finished.is_connected(_on_finished):
			seats[seat].speech_finished.connect(_on_finished)
	_books.clear()
	_voices.clear()
	_voice_banks.clear()
	_visit = null
	if app == null:
		return
	_visit = visit_stream(app.controller)
	for seat: int in seats:
		var book: SpeechBook = app.seat_speech(seat)
		if book != null:
			_books[seat] = book
		var voice: VoiceProfile = app.seat_voice(seat)
		if voice != null:
			_voices[seat] = voice
			_voice_banks[seat] = app.seat_voice_bank(seat)
		seats[seat].speech_skipped.connect(Audio.voice.stop)


## Speaks for event, if anyone would. A villager's last line goes when they act again,
## so nothing said about an earlier play stays up beside a later one.
func on_event(event: RunEvent) -> void:
	if event.type == RunEvent.Type.BID:
		_hush(event.seat)
		say(event.seat, "call" if event.value == 1 else "no_call")
		return
	if event.type != RunEvent.Type.ROUND:
		return
	var played: RoundEvent = event.round_event
	if played.type == RoundEvent.Type.PLAYED or played.type == RoundEvent.Type.PASSED:
		_hush(played.seat)
	match played.type:
		RoundEvent.Type.ROUND_STARTED:
			_landlord = played.seat
		RoundEvent.Type.PASSED:
			say(played.seat, "pass")
		RoundEvent.Type.ANNOUNCED:
			say(played.seat, "cards_left", {"count": played.value})
		RoundEvent.Type.PLAYED:
			var type: Pattern.Type = played.pattern.type
			if type == Pattern.Type.BOMB or type == Pattern.Type.ROCKET:
				say(played.seat, "bomb")
		RoundEvent.Type.ROUND_ENDED:
			for seat: int in _seats:
				var same_side: bool = (seat == _landlord) == (played.seat == _landlord)
				say(seat, "won" if same_side else "lost")


## How many lines this table has said, for tests.
func lines_said() -> int:
	var total: int = 0
	for seat: int in _said:
		total += _said[seat]
	return total


## Says one line for event at seat, if the seat has a panel and the book has a line.
func say(seat: int, event: String, fields: Dictionary = {}) -> void:
	if not _seats.has(seat):
		return
	if not hurrying and _talking_besides(seat):
		_wait({"seat": seat, "event": event, "fields": fields})
		return
	var said: int = _said.get(seat, 0)
	_said[seat] = said + 1
	var salt: int = said + seat * SEAT_SALT
	var choices: Array[SpeechLine] = BOOK.lines_for(event)
	if _books.has(seat):
		choices = _books[seat].lines_for(event) + choices
	if choices.is_empty():
		return
	var line: SpeechLine = choices[posmod(salt, choices.size())]
	var slogan: SpeechLine = _slogan(event, salt)
	if slogan != null:
		line = slogan
	var visit: SpeechLine = _visit_line(event)
	if visit != null:
		line = visit
	_speak(seat, event, line, fields)
	if line == slogan and _slogan_weight() >= dread.config.effect_tuning.unison_at:
		for other: int in _seats:
			if other != seat:
				_speak(other, event, line, fields)


## Shows and voices line at seat now.
func _speak(seat: int, event: String, line: SpeechLine, fields: Dictionary) -> void:
	var text: String = tr(line.text_key).format(fields)
	var reveal: PackedFloat32Array = PackedFloat32Array()
	if _voices.has(seat):
		var voice: VoiceProfile = _voices[seat]
		reveal = Audio.voice.speak(seat, text, line.mood, voice, _voice_banks[seat]).reveal
	_seats[seat].say(text, reveal)
	spoke.emit(seat, event, line)
	if hurrying:
		_seats[seat].skip_speech()


## A slogan in place of the line salt picks for event, at the share the slogan weight
## gives, or null.
func _slogan(event: String, salt: int) -> SpeechLine:
	var weight: float = _slogan_weight()
	if (
		weight <= 0.0
		or fposmod(salt * SPREAD, 1.0) >= dread.config.effect_tuning.slogan_share(weight)
	):
		return null
	var slogans: Array[SpeechLine] = BOOK.slogans_for(event)
	return null if slogans.is_empty() else slogans[posmod(salt, slogans.size())]


func _slogan_weight() -> float:
	return 0.0 if dread == null else dread.effect_weight(DreadEffects.SLOGANS)


## The stream the work team's lines draw on, seeded from the run, the Year and the Quota,
## or null when the run began with no entry in the family's file.
static func visit_stream(controller: RunController) -> RandomStream:
	if controller == null or not controller.has_run():
		return null
	var state: RunView = controller.run
	if state.file_entries() <= 0:
		return null
	var name: String = VISIT.stream % [state.year(), state.set_index()]
	return RandomStream.new(RandomStreams.derive_seed(state.run_seed(), name))


## One of the work team's lines in place of event's, at the data's chance, or null.
func _visit_line(event: String) -> SpeechLine:
	if _visit == null or event != VISIT.event or VISIT.lines.is_empty():
		return null
	if _visit.next_float() >= VISIT.chance:
		return null
	return VISIT.lines[_visit.next_int(0, VISIT.lines.size() - 1)]


## Shows every line still typing out, then every waiting line, and stops every voice.
func skip_all() -> void:
	hurrying = true
	for seat: int in _seats:
		_seats[seat].skip_speech()
	while not _waiting.is_empty():
		var line: Dictionary = _waiting.pop_front()
		say(line.seat, line.event, line.fields)
	hurrying = false
	Audio.voice.stop_all()


## Clears what seat last said, stops its voice and drops its waiting lines. If that
## leaves the table quiet, the next waiting line starts.
func _hush(seat: int) -> void:
	if not _seats.has(seat):
		return
	_waiting = _waiting.filter(func(line: Dictionary) -> bool: return line.seat != seat)
	if _voices.has(seat):
		Audio.voice.stop(seat)
	_seats[seat].say("")
	if not _waiting.is_empty() and not _talking_besides(Seats.NONE):
		_on_finished(seat)


func waiting_count() -> int:
	return _waiting.size()


func _wait(line: Dictionary) -> void:
	for index: int in _waiting.size():
		if _waiting[index].seat == line.seat and _waiting[index].event == line.event:
			_waiting.remove_at(index)
			break
	_waiting.append(line)
	if _waiting.size() <= QUEUE_MAX:
		return
	var dropped: int = 0
	for index: int in _waiting.size():
		if CHATTER.has(_waiting[index].event):
			dropped = index
			break
	_waiting.remove_at(dropped)


## True while a seat other than seat is typing out a line.
func _talking_besides(seat: int) -> bool:
	for other: int in _seats:
		if other != seat and _seats[other].is_typing():
			return true
	return false


func _on_finished(_seat: int) -> void:
	if _waiting.is_empty():
		return
	var line: Dictionary = _waiting.pop_front()
	say(line.seat, line.event, line.fields)
