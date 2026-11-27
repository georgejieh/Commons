class_name VoicePlayer
extends Node
## Villager voices, owned by the Audio autoload as Audio.voice. Each seat
## plays its family's pre-rendered letter sounds on the Voice bus, one per letter as the
## line types out, pitch-shifted for the line's contour. Nothing is synthesized live.
## Letters share one polyphonic stream per seat, so a new letter never cuts the last.
## Stopping a line plays no more letters; the one sounding is a few hundredths of a
## second with its own fade, so it ends cleanly on its own.

## The path of a letter's sound, filled with the letter bank's name and the letter.
const BANK_PATH: String = "res://audio/voices/%s/%s.wav"
## The letters that have a sound in a bank; any other character is only a pause.
const LETTERS: String = "abcdefghijklmnopqrstuvwxyz"
## Letters may overlap for a moment when a fast voice outruns a clip.
const POLYPHONY: int = 3

## 0 to 1, from the dread layers' weights: slows, narrows and quiets new lines.
var dread: float = 0.0

var _players: Array[AudioStreamPlayer] = []
var _playbacks: Array[AudioStreamPlaybackPolyphonic] = []
var _plans: Array[VoicePlan] = []
## Each seat's letter sounds by letter. A typed dictionary cannot be nested, so the values
## are Dictionary[String, AudioStream] kept as Dictionary.
var _banks: Array[Dictionary] = []
var _elapsed: PackedFloat32Array = PackedFloat32Array()
var _next: PackedInt32Array = PackedInt32Array()
var _played: PackedInt32Array = PackedInt32Array()
## Every bank loaded so far, by name, each a Dictionary[String, AudioStream].
var _loaded: Dictionary[String, Dictionary] = {}


func _init() -> void:
	for seat: int in Seats.COUNT:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		var mix: AudioStreamPolyphonic = AudioStreamPolyphonic.new()
		mix.polyphony = POLYPHONY
		player.stream = mix
		player.bus = AudioMixer.BUS_VOICE
		add_child(player)
		_players.append(player)
		_playbacks.append(null)
		_plans.append(null)
		_banks.append({})
	_elapsed.resize(Seats.COUNT)
	_next.resize(Seats.COUNT)
	_played.resize(Seats.COUNT)


func _process(delta: float) -> void:
	advance(delta)


## Starts seat saying text in voice, from the letter bank named bank, and returns the
## plan so the text can type out in step. A line already playing at that seat stops.
func speak(seat: int, text: String, mood: String, voice: VoiceProfile, bank: String) -> VoicePlan:
	var plan: VoicePlan = VoiceScript.plan(text, mood, voice, dread)
	_plans[seat] = plan
	_banks[seat] = _bank(bank)
	_elapsed[seat] = 0.0
	_next[seat] = 0
	return plan


## Sets dread from the dread layers' shown weights: the strongest one. No allocation.
func follow(board: BoardState, layers: Array[HorrorLayer], intensity: float) -> void:
	var strongest: float = 0.0
	for index: int in layers.size():
		strongest = maxf(strongest, board.shown(index, intensity))
	dread = strongest


## Plays no more of seat's line.
func stop(seat: int) -> void:
	_plans[seat] = null


## Plays no more of any seat's line.
func stop_all() -> void:
	for seat: int in Seats.COUNT:
		stop(seat)


## Stops every voice and clears dread, as when leaving the table.
func reset() -> void:
	stop_all()
	dread = 0.0


## True from a line's first syllable until its last has played, so a new line waits.
func is_speaking(seat: int) -> bool:
	return _plans[seat] != null


## Letter sounds started at seat since the game began, for tests.
func letters_played(seat: int) -> int:
	return _played[seat]


## Moves every line on by seconds, starting the letters now due. No allocation.
func advance(seconds: float) -> void:
	for seat: int in Seats.COUNT:
		var plan: VoicePlan = _plans[seat]
		if plan == null:
			continue
		_elapsed[seat] += seconds
		while _next[seat] < plan.letters.size() and plan.times[_next[seat]] <= _elapsed[seat]:
			_play(seat, plan, _next[seat])
			_next[seat] += 1
		if _next[seat] >= plan.letters.size() and _elapsed[seat] >= plan.length:
			_plans[seat] = null


func _play(seat: int, plan: VoicePlan, index: int) -> void:
	_played[seat] += 1
	var stream: AudioStream = _banks[seat].get(plan.letters[index])
	if stream == null:
		return
	var playback: AudioStreamPlaybackPolyphonic = _playback(seat)
	if playback != null:
		playback.play_stream(stream, 0.0, plan.volumes_db[index], plan.pitches[index])


## The seat's polyphonic playback, started on first use, once the player is in a tree.
func _playback(seat: int) -> AudioStreamPlaybackPolyphonic:
	if _playbacks[seat] == null and _players[seat].is_inside_tree():
		_players[seat].play()
		_playbacks[seat] = _players[seat].get_stream_playback()
	return _playbacks[seat]


## A bank's letter sounds, loaded once. A missing bank stays silent.
func _bank(bank: String) -> Dictionary[String, AudioStream]:
	if _loaded.has(bank):
		return _loaded[bank]
	var sounds: Dictionary[String, AudioStream] = {}
	for index: int in LETTERS.length():
		var path: String = BANK_PATH % [bank, LETTERS[index]]
		if not bank.is_empty() and ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			sounds[LETTERS[index]] = stream
	_loaded[bank] = sounds
	return sounds
