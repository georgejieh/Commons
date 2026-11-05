class_name MusicPlayer
extends Node
## Music (P3C.9), owned by the Audio autoload as Audio.music: plays one cue at a time
## on the Music bus, its stems in one AudioStreamSynchronized so they share a timeline.
## A stem fades by volume only and keeps playing at zero gain, so it returns in the
## right place. A new cue starts on the
## next bar line of the one playing. Cues with no audio are silent, so the game runs the
## same before the music exists.

const SCORE: MusicScore = preload("res://data/audio/music_score.tres")
const SILENT_DB: float = -80.0
## Cue changes wait at most this long past a bar line before they start.
const BAR_SLACK: float = 0.03

var _player: AudioStreamPlayer = AudioStreamPlayer.new()
var _current: MusicCue = null
var _pending: MusicCue = null
var _gains: PackedFloat32Array = []
var _targets: PackedFloat32Array = []


func _init() -> void:
	_player.bus = "Music"
	add_child(_player)


## The id of the cue playing, or "" when silent.
func current_id() -> String:
	return _current.id if _current != null else ""


## Asks for a cue. It starts now if nothing plays, else on the next bar line.
func request(cue_id: String) -> void:
	var cue: MusicCue = SCORE.cue(cue_id)
	if cue == null or cue == _current or cue == _pending:
		return
	if _current == null or not _player.playing:
		_start(cue)
	else:
		_pending = cue


## Sets each stem's target gain from the dread layers' shown weights. No allocation.
func follow(board: BoardState, layers: Array[HorrorLayer], intensity: float) -> void:
	if _current == null:
		return
	for stem: int in _targets.size():
		var gain: float = 1.0
		var name: String = _current.stem_names[stem]
		for index: int in layers.size():
			if layers[index].audio_stems.has(name):
				gain = minf(gain, 1.0 - board.shown(index, intensity))
		_targets[stem] = gain


## A stem's current gain, 0 to 1, or -1 when the cue has no such stem.
func stem_gain(stem: String) -> float:
	if _current == null:
		return -1.0
	var index: int = _current.stem_names.find(stem)
	return _gains[index] if index >= 0 else -1.0


## Seconds from position to the next bar line of cue.
static func seconds_to_bar(cue: MusicCue, position: float) -> float:
	var bar: float = cue.bar_seconds()
	var into: float = fmod(position, bar)
	return 0.0 if into < BAR_SLACK else bar - into


func _process(delta: float) -> void:
	if _pending != null and seconds_to_bar(_current, _player.get_playback_position()) <= 0.0:
		_start(_pending)
	if _current == null:
		return
	var step: float = delta / maxf(SCORE.fade_seconds, 0.01)
	var mix: AudioStreamSynchronized = _player.stream as AudioStreamSynchronized
	for stem: int in _gains.size():
		_gains[stem] = move_toward(_gains[stem], _targets[stem], step)
		if mix != null:
			var db: float = maxf(linear_to_db(_gains[stem]), SILENT_DB)
			mix.set_sync_stream_volume(stem, db)


func _start(cue: MusicCue) -> void:
	_pending = null
	_current = cue
	_gains.resize(cue.stem_names.size())
	_gains.fill(1.0)
	_targets.resize(cue.stem_names.size())
	_targets.fill(1.0)
	_player.stop()
	if not cue.has_audio():
		_player.stream = null
		return
	var mix: AudioStreamSynchronized = AudioStreamSynchronized.new()
	mix.stream_count = cue.stems.size()
	for index: int in cue.stems.size():
		mix.set_sync_stream(index, cue.stems[index])
	_player.stream = mix
	_player.play()
