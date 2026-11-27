class_name MusicPlayer
extends Node
## Music, owned by the Audio autoload as Audio.music: plays one cue at a time
## on the Music bus, its stems in one AudioStreamSynchronized so they share a timeline.
## A stem fades by volume only and keeps playing at zero gain, so it returns in the
## right place. A new cue starts when playback crosses the next bar line of the one
## playing, measured from the cue's first downbeat. Cues with no audio are silent, so
## the game runs the same before the music exists.

## The music score: the cues, their stems and bar timings, and the stem fade.
const SCORE: MusicScore = preload("res://data/audio/music_score.tres")

## Plays the cue's stems as one synchronized stream on the Music bus.
var player: AudioStreamPlayer = AudioStreamPlayer.new()
var _current: MusicCue = null
var _pending: MusicCue = null
var _gains: PackedFloat32Array = []
var _targets: PackedFloat32Array = []
## The bar the playback was in last frame, so a crossing is never missed.
var _last_bar: int = -1


## The bar that position falls in, counted from the cue's first downbeat; -1 before it.
static func bar_at(cue: MusicCue, position: float) -> int:
	if position < cue.downbeat:
		return -1
	return int(floor((position - cue.downbeat) / cue.bar_seconds()))


func _init() -> void:
	player.bus = AudioMixer.BUS_MUSIC
	add_child(player)


func _process(delta: float) -> void:
	if _current == null:
		return
	check_bar(player.get_playback_position() if player.playing else 0.0)
	var step: float = delta / maxf(SCORE.fade_seconds, 0.01)
	var mix: AudioStreamSynchronized = player.stream as AudioStreamSynchronized
	for stem: int in _gains.size():
		_gains[stem] = move_toward(_gains[stem], _targets[stem], step)
		if mix != null:
			var db: float = maxf(linear_to_db(_gains[stem]), AudioMixer.SILENT_DB)
			mix.set_sync_stream_volume(stem, db)


## Starts the waiting cue once playback has crossed into a new bar, or wrapped round the
## loop, since the last frame. A silent cue has no bars, so the change happens at once.
func check_bar(position: float) -> void:
	var bar: int = bar_at(_current, position)
	var crossed: bool = bar != _last_bar and _last_bar >= 0
	_last_bar = bar
	if _pending != null and (crossed or not _current.has_audio()):
		_start(_pending)


## The id of the cue playing, or "" when silent.
func current_id() -> String:
	return _current.id if _current != null else ""


## The id of the cue waiting for the next bar line, or "".
func pending_id() -> String:
	return _pending.id if _pending != null else ""


## Asks for a cue. It starts now if nothing plays, else on the next bar line. Asking for
## the cue already playing cancels any change still waiting.
func request(cue_id: String) -> void:
	var cue: MusicCue = SCORE.cue(cue_id)
	if cue == null:
		return
	if cue == _current:
		_pending = null
		return
	if _current == null or not player.playing:
		_start(cue)
	else:
		_pending = cue


## Sets each stem's target gain from the dread layers' shown weights. No allocation.
func follow(board: BoardState, layers: Array[HorrorLayer], intensity: float) -> void:
	if _current == null:
		return
	for stem: int in _targets.size():
		var gain: float = 1.0
		var stem_name: String = _current.stem_names[stem]
		for index: int in layers.size():
			if layers[index].audio_stems.has(stem_name):
				gain = minf(gain, 1.0 - board.shown(index, intensity))
		_targets[stem] = gain


## Brings every stem back to full, as on the clean board.
func relax() -> void:
	_targets.fill(1.0)


## A stem's current gain, 0 to 1, or -1 when the cue has no such stem.
func stem_gain(stem: String) -> float:
	if _current == null:
		return -1.0
	var index: int = _current.stem_names.find(stem)
	return _gains[index] if index >= 0 else -1.0


func _start(cue: MusicCue) -> void:
	# Stems that both cues share keep their gain, so a held-down stem stays down.
	var carried: PackedFloat32Array = []
	carried.resize(cue.stem_names.size())
	carried.fill(1.0)
	if _current != null:
		for index: int in cue.stem_names.size():
			var before: int = _current.stem_names.find(cue.stem_names[index])
			if before >= 0:
				carried[index] = _targets[before]
	_pending = null
	_current = cue
	_gains = carried.duplicate()
	_targets = carried
	_last_bar = -1
	player.stop()
	if not cue.has_audio():
		player.stream = null
		return
	var mix: AudioStreamSynchronized = AudioStreamSynchronized.new()
	mix.stream_count = cue.stems.size()
	for index: int in cue.stems.size():
		mix.set_sync_stream(index, cue.stems[index])
		mix.set_sync_stream_volume(index, maxf(linear_to_db(_gains[index]), AudioMixer.SILENT_DB))
	player.stream = mix
	player.play()
