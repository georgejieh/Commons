class_name SettingsParams
extends Resource
## Default player settings. A player's changes are saved over these.

## Linear volume per audio bus, 0 to 1.
@export var music_volume: float = 0.8
## Linear volume of the Effects bus, 0 to 1.
@export var effects_volume: float = 0.8
## Linear volume of the Voice bus, 0 to 1.
@export var voice_volume: float = 0.8
## Scales or disables shake, hit-stop and other motion.
@export var reduced_motion: bool = false
## The full-screen print and grain pass. Off is the low-quality setting.
@export var post_process: bool = true
## Scales every dread layer, 0 (the clean board) to 1.
@export var horror_intensity: float = 1.0
## Turns off every flicker and the lamp's flutter.
@export var no_flash: bool = false
## Set once the first-launch content note has been read.
@export var content_note_seen: bool = false
## The card back design chosen (ADR 0025): cosmetic, per player.
@export var card_back: String = "sunrise"
## The text size chosen (ADR 0034): an index into text_scales, 0 for Standard.
@export var text_size: int = 0
## The table's pace chosen: an index into MotionPresets.pace_scales, 1 for Standard.
@export var table_pace: int = 1
## Whether the table offers its Hint button (HintSetting).
@export var show_hint: bool = true
## The window (DisplayWindow): 0 a window, 1 borderless full screen, 2 exclusive full
## screen. A number, as DisplayWindow's modes are the UI's and data cannot name ui/.
@export var window_mode: int = 1
## The size of a window: an index into window_sizes.
@export var window_size: int = 2
## Whether each frame waits for the screen's refresh.
@export var vsync: bool = true

@export_group("Text size")
## What each text size multiplies every font size by: Standard, Large, Largest. Not saved.
@export var text_scales: Array[float] = [1.0, 1.15, 1.3]
## The least font size, in canvas pixels, anything the player reads is set at. Not saved.
@export var least_text_px: int = 14
## Display type holds (ADR 0034): a base size this large or larger, the title and
## headline steps and the ending's title, does not grow. Not saved.
@export var display_text_px: int = 40

@export_group("Display")
## The sizes offered for a window, smallest first, all 16:9 like the canvas, which
## stretches to fill them. Not saved.
@export var window_sizes: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)
]
## How many seconds a new window mode or size stands unkept before the old one comes
## back. Not saved.
@export var display_check_seconds: int = 10
