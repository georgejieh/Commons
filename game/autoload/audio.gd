class_name AudioMixer
extends Node
## The Audio autoload: the Music, Effects and Voice buses and their volumes, set from the
## Settings autoload, and the Ambience bus under Effects. play() takes a named audio
## event and plays its sound effect; a name with no sound is silent. Every button
## clicks.

## The bus the music plays on.
const BUS_MUSIC: String = "Music"
## The bus the sound effects play on.
const BUS_EFFECTS: String = "Effects"
## The bus the villagers' voices play on.
const BUS_VOICE: String = "Voice"
## The ambience has no volume of its own: the settings sheet has no room for a fourth, so
## its bus sends to Effects and the Effects volume governs it.
const BUS_AMBIENCE: String = "Ambience"
## Each bus that has a volume setting, and the key of that setting.
const BUSES: Dictionary[String, String] = {
	BUS_MUSIC: "music_volume", BUS_EFFECTS: "effects_volume", BUS_VOICE: "voice_volume"
}
## The level, in decibels, a gain of zero is held at instead of minus infinity.
const SILENT_DB: float = -80.0
## The click every button makes when pressed.
const CLICK: String = "button_click"
## A motion's own sound plays only into a silence: not when another effect started this
## close before it, as when the event it shows already has a sound.
const FILL_GUARD_MSEC: int = 70

## The last event name played, for tests.
var last_played: String = ""
## The music cues and their stems.
var music: MusicPlayer = MusicPlayer.new()
## Villager voices.
var voice: VoicePlayer = VoicePlayer.new()
## The sound effects.
var effects: SfxPlayer = SfxPlayer.new()
## The beds under the table.
var ambience: AmbiencePlayer = AmbiencePlayer.new()
## The last motion sound filled in, for tests.
var last_filled: String = ""
var _click: Callable = play.bind(CLICK)
var _played_msec: int = -FILL_GUARD_MSEC


func _init() -> void:
	add_child(music)
	add_child(voice)
	add_child(effects)
	add_child(ambience)


func _ready() -> void:
	ensure_buses()
	Settings.changed.connect(_on_setting_changed)
	for bus: String in BUSES:
		_apply_volume(bus)
	get_tree().node_added.connect(_on_node_added)


## Adds any missing bus, sent to Master, the Ambience bus sent to Effects and keyed down
## by the Voice bus, and a limiter on Master.
func ensure_buses() -> void:
	for bus: String in BUSES:
		_ensure_bus(bus, "Master")
	if _ensure_bus(BUS_AMBIENCE, BUS_EFFECTS):
		var index: int = AudioServer.get_bus_index(BUS_AMBIENCE)
		AudioServer.add_bus_effect(index, AmbiencePlayer.SCORE.voice_duck(BUS_VOICE))
	# Sounds add up, so Master never clips.
	for effect: int in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, effect) is AudioEffectHardLimiter:
			return
	AudioServer.add_bus_effect(0, AudioEffectHardLimiter.new())


func _apply_volume(bus: String) -> void:
	var linear: float = float(Settings.value(BUSES[bus]))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(linear))


func _on_setting_changed(key: String) -> void:
	for bus: String in BUSES:
		if BUSES[bus] == key:
			_apply_volume(bus)


## Plays the sound for a named event, semitones above its own pitch.
func play(event_name: String, semitones: float = 0.0) -> void:
	last_played = event_name
	ambience.duck_for(event_name)
	_sounded(effects.play(event_name, semitones))


## Plays a motion's sound at the end of the frame, unless an effect has just started or
## starts in the same frame: a moment whose event has a sound keeps that one alone.
func fill(event_name: String) -> void:
	_fill_now.call_deferred(event_name)


func _fill_now(event_name: String) -> void:
	if Time.get_ticks_msec() - _played_msec < FILL_GUARD_MSEC:
		return
	last_filled = event_name
	_sounded(effects.play(event_name))


func _sounded(played: bool) -> void:
	if played:
		_played_msec = Time.get_ticks_msec()


## Adds a bus sent to another unless it exists; true when it was added. A bus sends only
## to one before it, so it goes last.
static func _ensure_bus(bus: String, send: String) -> bool:
	if AudioServer.get_bus_index(bus) != -1:
		return false
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, send)
	return true


## Gives every button its click, wherever it is built, so screens need no sound code.
func _on_node_added(node: Node) -> void:
	var button: BaseButton = node as BaseButton
	if button != null and not button.pressed.is_connected(_click):
		button.pressed.connect(_click)
