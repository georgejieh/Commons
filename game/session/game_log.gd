class_name GameLog
extends RefCounted
## The few lines the game adds to the engine's log (ADR 0037): one at start, one when a
## run starts, resumes or ends, and one for each save or load that fails or falls back to
## its backup. Nothing is printed each frame or each turn. No line holds a family name,
## anything the player typed, or a path outside the game's own folder: a file is named by
## its name alone. Every line starts with PREFIX, so a tool can pick them out.

const PREFIX: String = "Commons: "
const VERSION_SETTING: String = "application/config/version"
## How the start line begins, which marks a log as the game's own and not a tool's.
const STARTED: String = PREFIX + "version "
## How the line for a load that fell back to its backup ends.
const FELL_BACK: String = "fell back to its backup"


## The build, the system, the renderer and the screen.
static func started() -> void:
	var version: String = str(ProjectSettings.get_setting(VERSION_SETTING, ""))
	var screen: Vector2i = DisplayServer.screen_get_size()
	_line(
		(
			"version %s, %s build, %s, %s renderer, screen %dx%d"
			% [
				version if not version.is_empty() else "unnumbered",
				"release" if FileMode.release_build() else "development",
				OS.get_name(),
				RenderingServer.get_current_rendering_method(),
				screen.x,
				screen.y,
			]
		)
	)


## A run of the given kind ("full" or "demo") started from seed.
static func run_started(kind: String, seed_value: int) -> void:
	_line(
		"%s run started, seed %d, save schema %d" % [kind, seed_value, SaveService.SCHEMA_VERSION]
	)


static func run_resumed(seed_value: int) -> void:
	_line("run resumed, seed %d, save schema %d" % [seed_value, SaveService.SCHEMA_VERSION])


## A run ended: how is "finished" or "abandoned".
static func run_ended(seed_value: int, how: String) -> void:
	_line("run %s, seed %d" % [how, seed_value])


static func save_failed(file_path: String, error: Error) -> void:
	_line("save of %s failed: %s" % [file_path.get_file(), error_string(error)])


static func load_fell_back(file_path: String) -> void:
	_line("load of %s %s" % [file_path.get_file(), FELL_BACK])


static func load_failed(file_path: String) -> void:
	_line("load of %s failed: neither it nor its backup reads" % file_path.get_file())


## The last session did not close, and its files were copied into a folder.
static func crash_kept(folder: String) -> void:
	_line("the last session did not close; its files were copied to %s" % folder.get_file())


static func _line(text: String) -> void:
	print(PREFIX + text)
