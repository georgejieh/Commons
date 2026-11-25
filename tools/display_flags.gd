class_name DisplayFlags
extends RefCounted
## The display flags of the playtest tools (ADR 0035), shared by tools/playtest.gd and
## tools/demo_screenshots.gd:
##   --grayscale       a full-screen grayscale pass over everything the tool shows, on a
##                     canvas layer above every other; a test fixture, never a setting
##   --reduced-motion  the reduced-motion setting, for this run
##   --text-size N     0 Standard, 1 Large, 2 Largest (ADR 0034), for this run
## With any of them given, the settings save to the tool's own file in its sandbox folder
## (WalkProfile) from then on, so what a run sets never reaches the player's.
## Development only; tools/ never ships.

const GRAYSCALE: String = "grayscale"
const REDUCED_MOTION: String = "reduced-motion"
const TEXT_SIZE: String = "text-size"
## The reduced-motion setting's key. Its owner, UiMotion.SETTING, names the Settings
## autoload, which a --script tool cannot compile against.
const REDUCED_MOTION_KEY: String = "reduced_motion"
const TEXT_SIZE_KEY: String = TextSize.SETTING
## Above PostProcess.LAYER and every layer the game makes.
const LAYER: int = 128
const SAVE_FILE: String = "tool_settings.cfg"
## The sandbox folder the settings file goes in, as the playtest's own saves do.
const PROFILE_BASE: String = "playtest"
const SHADER: String = """
shader_type canvas_item;
uniform sampler2D screen: hint_screen_texture, filter_linear;
void fragment() {
	vec3 seen = texture(screen, SCREEN_UV).rgb;
	COLOR = vec4(vec3(dot(seen, vec3(0.299, 0.587, 0.114))), 1.0);
}
"""


## True when the tool was given any of the flags.
static func any(options: ToolOptions) -> bool:
	return options.has(GRAYSCALE) or options.has(REDUCED_MOTION) or options.has(TEXT_SIZE)


## The text size asked for, or -1 when none was; a size out of range is a fault in options.
static func text_size(options: ToolOptions) -> int:
	return options.integer(TEXT_SIZE, -1, 0, TextSize.count() - 1)


## The Settings autoload under root.
static func settings(root: Window) -> SettingsStore:
	return root.get_node(SettingsStore.AUTOLOAD) as SettingsStore


## Applies the flags in options to the running tool, before the app is made, and says
## what it applied.
static func apply(root: Window, options: ToolOptions) -> String:
	if not any(options):
		return "display flags: none"
	var store: SettingsStore = settings(root)
	var folder: String = WalkProfile.folder(PROFILE_BASE, options)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	store.save_to(folder + SAVE_FILE)
	var reduced: bool = options.has(REDUCED_MOTION)
	if reduced:
		store.set_value(REDUCED_MOTION_KEY, true)
	var size: int = text_size(options)
	if size >= 0:
		store.set_value(TEXT_SIZE_KEY, size)
	var gray: bool = options.has(GRAYSCALE)
	if gray:
		root.add_child(_grayscale())
	return "display flags: grayscale=%s reduced_motion=%s text_size=%d" % [gray, reduced, size]


static func _grayscale() -> CanvasLayer:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "GrayscalePass"
	layer.layer = LAYER
	var shader: Shader = Shader.new()
	shader.code = SHADER
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	var pass_rect: ColorRect = ColorRect.new()
	pass_rect.material = material
	pass_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pass_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(pass_rect)
	return layer
