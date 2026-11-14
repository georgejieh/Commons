class_name AudioMixer
extends Node
## The Audio autoload: the Music, Effects and Voice buses and their volumes, set from the
## Settings autoload. play() takes a named audio event (P3B.10) and plays its sound
## effect (P3C.8); a name with no sound is silent. Every button clicks.

const BUSES: Dictionary[String, String] = {
	"Music": "music_volume", "Effects": "effects_volume", "Voice": "voice_volume"
}

## The click every button makes when pressed.
const CLICK: String = "button_click"

## The last event name played, for tests and a debug overlay.
var last_played: String = ""
## The music cues and their stems (P3C.9).
var music: MusicPlayer = MusicPlayer.new()
## Villager voices (P3B.13).
var voice: VoicePlayer = VoicePlayer.new()
## The sound effects (P3C.8).
var effects: SfxPlayer = SfxPlayer.new()
var _click: Callable = play.bind(CLICK)


func _init() -> void:
	add_child(music)
	add_child(voice)
	add_child(effects)


func _ready() -> void:
	ensure_buses()
	Settings.changed.connect(_on_setting_changed)
	for bus: String in BUSES:
		apply_volume(bus)
	get_tree().node_added.connect(_on_node_added)


## Adds any missing bus, sent to Master, and a limiter on Master.
func ensure_buses() -> void:
	for bus: String in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var index: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
	# Sounds add up, so Master never clips.
	for effect: int in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, effect) is AudioEffectHardLimiter:
			return
	AudioServer.add_bus_effect(0, AudioEffectHardLimiter.new())


func apply_volume(bus: String) -> void:
	var linear: float = float(Settings.value(BUSES[bus]))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(linear))


func _on_setting_changed(key: String) -> void:
	for bus: String in BUSES:
		if BUSES[bus] == key:
			apply_volume(bus)


## Plays the sound for a named event.
func play(event_name: String) -> void:
	last_played = event_name
	effects.play(event_name)


## Gives every button its click, wherever it is built, so screens need no sound code.
func _on_node_added(node: Node) -> void:
	var button: BaseButton = node as BaseButton
	if button != null and not button.pressed.is_connected(_click):
		button.pressed.connect(_click)
