class_name AmbiencePlayer
extends Node
## The ambience under the table, owned by the Audio autoload as Audio.ambience:
## one looping player per bed on the Ambience bus, made once. DreadLayers passes the
## shown layer weights every frame; each bed's gain eases toward what they ask for over
## the score's fade_seconds. A bed at zero is paused, so it costs nothing in the mix. It
## is silent until the table first follows the board, so the title has none.

## The ambience score: the beds to loop, their gains, and the fade, duck and hush timings.
const SCORE: AmbienceScore = preload("res://data/audio/ambience_score.tres")

var _players: Array[AudioStreamPlayer] = []
var _gains: PackedFloat32Array = []
var _targets: PackedFloat32Array = []
var _hushed: Array[bool] = []
## The dip under hero effects and the hush after the player's play, 0 to 1, with the
## seconds each is held before it returns.
var _duck: float = 1.0
var _duck_floor: float = 1.0
var _duck_wait: float = 0.0
var _hush: float = 1.0
var _hush_wait: float = 0.0


## How far a bed's naming layers move it from where it sits on the clean board.
static func gain_for(
	bed: AmbienceBed, board: BoardState, layers: Array[HorrorLayer], intensity: float
) -> float:
	var gain: float = 1.0 if bed.on_clean_board else 0.0
	for index: int in layers.size():
		if not layers[index].audio_stems.has(bed.id):
			continue
		var moved: float = HorrorLayer.along(bed.response, board.shown(index, intensity))
		gain = minf(gain, 1.0 - moved) if bed.on_clean_board else maxf(gain, moved)
	return clampf(gain, 0.0, 1.0)


## One frame of a dip: toward low over attack seconds while held, then back to full
## over release seconds, linear in gain.
static func dip(
	value: float, low: float, held: bool, attack: float, release: float, delta: float
) -> float:
	var seconds: float = attack if held else release
	return move_toward(value, low if held else 1.0, delta * (1.0 - low) / maxf(seconds, 0.001))


func _init() -> void:
	_duck_floor = db_to_linear(SCORE.duck_db)
	for bed: AmbienceBed in SCORE.beds:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = bed.stream
		player.bus = AudioMixer.BUS_AMBIENCE
		player.volume_db = AudioMixer.SILENT_DB
		add_child(player)
		_players.append(player)
		_hushed.append(SCORE.hush_beds.has(bed.id))
	_gains.resize(SCORE.beds.size())
	_targets.resize(SCORE.beds.size())


func _process(delta: float) -> void:
	var step: float = delta / maxf(SCORE.fade_seconds, 0.01)
	for index: int in _gains.size():
		_gains[index] = move_toward(_gains[index], _targets[index], step)
	_duck_wait = maxf(_duck_wait - delta, 0.0)
	_duck = AmbiencePlayer.dip(
		_duck,
		_duck_floor,
		_duck_wait > 0.0,
		SCORE.duck_attack_seconds,
		SCORE.duck_release_seconds,
		delta
	)
	_hush_wait = maxf(_hush_wait - delta, 0.0)
	_hush = AmbiencePlayer.dip(
		_hush, 0.0, _hush_wait > 0.0, SCORE.hush_attack_seconds, SCORE.hush_release_seconds, delta
	)
	for index: int in _players.size():
		_sound(_players[index], _level(index), SCORE.beds[index].volume_db)


## Sets each bed's target from the dread layers' shown weights. No allocation.
func follow(board: BoardState, layers: Array[HorrorLayer], intensity: float) -> void:
	for index: int in SCORE.beds.size():
		_targets[index] = AmbiencePlayer.gain_for(SCORE.beds[index], board, layers, intensity)


## Fades every bed out, as when leaving the table.
func silence() -> void:
	_targets.fill(0.0)


## Dips the beds under an effect when the score names it.
func duck_for(event_name: String) -> void:
	if SCORE.duck_events.has(event_name):
		_duck_wait = SCORE.duck_hold_seconds + SCORE.duck_attack_seconds


## Hushes the beds the score names, as the crowd stops when the player plays.
func hush() -> void:
	_hush_wait = SCORE.hush_hold_seconds + SCORE.hush_attack_seconds


## A bed's gain, 0 to 1, before any dip or hush, or -1 when there is no such bed; for tests.
func bed_gain(bed_id: String) -> float:
	var index: int = SCORE.beds.find(SCORE.bed(bed_id))
	return _gains[index] if index >= 0 else -1.0


## The level a bed plays at now, 0 to 1, with its dip and hush; for tests.
func bed_level(bed_id: String) -> float:
	var index: int = SCORE.beds.find(SCORE.bed(bed_id))
	return _level(index) if index >= 0 else 0.0


func _level(index: int) -> float:
	return _gains[index] * _duck * (_hush if _hushed[index] else 1.0)


## Plays a bed at a level, pausing it at zero so a silent loop is not mixed.
func _sound(player: AudioStreamPlayer, level: float, volume_db: float) -> void:
	if level <= 0.0:
		if player.playing:
			player.stream_paused = true
		return
	player.volume_db = maxf(volume_db + linear_to_db(level), AudioMixer.SILENT_DB)
	if player.stream_paused:
		player.stream_paused = false
	elif not player.playing:
		player.play()
