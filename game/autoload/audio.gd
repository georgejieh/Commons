class_name AudioMixer
extends Node
## The Audio autoload: the Music, Effects and Voice buses and their volumes, set from the
## Settings autoload. play() takes a named audio event (P3B.10); every name is silent
## until P3C.8 brings the sounds.

const BUSES: Dictionary[String, String] = {
	"Music": "music_volume", "Effects": "effects_volume", "Voice": "voice_volume"
}

## The last event name played, for tests and a debug overlay.
var last_played: String = ""


func _ready() -> void:
	ensure_buses()
	Settings.changed.connect(_on_setting_changed)
	for bus: String in BUSES:
		apply_volume(bus)


## Adds any missing bus, sent to Master.
func ensure_buses() -> void:
	for bus: String in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var index: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")


func apply_volume(bus: String) -> void:
	var linear: float = float(Settings.value(BUSES[bus]))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(linear))


func _on_setting_changed(key: String) -> void:
	for bus: String in BUSES:
		if BUSES[bus] == key:
			apply_volume(bus)


## Plays the sound for a named event. Silent placeholder until P3C.8.
func play(event_name: String) -> void:
	last_played = event_name
