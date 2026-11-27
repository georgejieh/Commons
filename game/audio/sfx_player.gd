class_name SfxPlayer
extends Node
## Sound effects, owned by the Audio autoload as Audio.effects: one player per
## take on the Effects bus, because changing a player's stream cuts the copies still
## ringing. Takes play round-robin, pitch nudged from the cosmetic random stream. Events
## with no sound in the bank stay silent.

## The bank of sound effects, each with its takes, volume, pitch spread and voices.
const BANK: SfxBank = preload("res://data/audio/sfx_bank.tres")

## The cosmetic stream is outside any run, so sound never moves a run's random state.
var _random: RandomStream = RandomStream.new(RandomStreams.derive_seed(0, RandomStreams.COSMETIC))
var _players: Dictionary[String, AudioStreamPlayer] = {}
var _next_take: Dictionary[String, int] = {}


## Plays the sound for an event name, semitones above its own pitch, so a scored
## play's ticks and chimes can step up or down as they go. Returns false when the event has
## no sound.
func play(id: String, semitones: float = 0.0) -> bool:
	var sound: SfxSound = BANK.sound(id)
	if sound == null or sound.streams.is_empty():
		return false
	var take: int = _next_take.get(id, 0)
	_next_take[id] = (take + 1) % sound.streams.size()
	var player: AudioStreamPlayer = _player_for(sound, take)
	var shift: float = (_random.next_float() * 2.0 - 1.0) * sound.pitch_semitones + semitones
	player.pitch_scale = pow(2.0, shift / 12.0)
	player.play()
	return true


## The take the next play of a sound will use, for tests.
func next_take(id: String) -> int:
	return _next_take.get(id, 0)


func _player_for(sound: SfxSound, take: int) -> AudioStreamPlayer:
	var key: String = "%s:%d" % [sound.id, take]
	if _players.has(key):
		return _players[key]
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = sound.streams[take]
	player.bus = AudioMixer.BUS_EFFECTS
	player.volume_db = sound.volume_db
	player.max_polyphony = maxi(sound.voices, 1)
	add_child(player)
	_players[key] = player
	return player
