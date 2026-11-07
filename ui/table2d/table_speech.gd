class_name TableSpeech
extends RefCounted
## Turns run events into what villagers say at the table (P3B.8). Lines come from the
## SpeechBook by event. Each seat cycles through a salt, so the same events in the same
## order always give the same lines, with no global random.

## A villager said a line: the voice (P3B.13) listens here.
signal spoke(seat: int, event: String, line: SpeechLine)

const BOOK: SpeechBook = preload("res://data/ui/speech_book.tres")
## Spreads the seats' salts so two villagers rarely say the same line together.
const SEAT_SALT: int = 7

var _seats: Dictionary[int, SeatPanel] = {}
var _said: Dictionary[int, int] = {}
var _landlord: int = Seats.NONE
## Each seated family's own lines (P4.5), said alongside the shared book's.
var _books: Dictionary[int, SpeechBook] = {}
## Each seat's voice and letter bank (P3B.13). A seat with none speaks silently.
var _voices: Dictionary[int, VoiceProfile] = {}
var _voice_banks: Dictionary[int, String] = {}


func setup(seats: Dictionary[int, SeatPanel], app: DemoApp = null) -> void:
	_seats = seats
	_books.clear()
	_voices.clear()
	_voice_banks.clear()
	if app == null:
		return
	for seat: int in seats:
		var book: SpeechBook = app.seat_speech(seat)
		if book != null:
			_books[seat] = book
		var voice: VoiceProfile = app.seat_voice(seat)
		if voice != null:
			_voices[seat] = voice
			_voice_banks[seat] = app.seat_voice_bank(seat)
		seats[seat].speech_skipped.connect(Audio.voice.stop)


## Speaks for event, if anyone would.
func on_event(event: RunEvent) -> void:
	if event.type == RunEvent.Type.BID:
		say(event.seat, "call" if event.value == 1 else "no_call")
		return
	if event.type != RunEvent.Type.ROUND:
		return
	var played: RoundEvent = event.round_event
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
	var said: int = _said.get(seat, 0)
	_said[seat] = said + 1
	var choices: Array[SpeechLine] = BOOK.lines_for(event)
	if _books.has(seat):
		choices = _books[seat].lines_for(event) + choices
	if choices.is_empty():
		return
	var line: SpeechLine = choices[posmod(said + seat * SEAT_SALT, choices.size())]
	var text: String = tr(line.text_key).format(fields)
	var reveal: PackedFloat32Array = PackedFloat32Array()
	if _voices.has(seat):
		var voice: VoiceProfile = _voices[seat]
		reveal = Audio.voice.speak(seat, text, line.mood, voice, _voice_banks[seat]).reveal
	_seats[seat].say(text, line.mood, reveal)
	spoke.emit(seat, event, line)


## Shows every line still typing out and stops every voice.
func skip_all() -> void:
	for seat: int in _seats:
		_seats[seat].skip_speech()
	Audio.voice.stop_all()
