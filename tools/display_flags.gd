extends RefCounted
## The display flags of the playtest tools (ADR 0035), shared by tools/playtest.gd and
## tools/demo_screenshots.gd:
##   --grayscale       a full-screen grayscale pass over everything the tool shows, on a
##                     canvas layer above every other; a test fixture, never a setting
##   --reduced-motion  the reduced-motion setting, for this run
##   --text-size N     0 Standard, 1 Large, 2 Largest (ADR 0034), for this run
## With any of them given, the settings save to the tool's own file from then on, so what
## a run sets never reaches the player's. Loaded at run time by path: it names the
## Settings autoload, which a --script tool cannot see when it compiles.
## Development only; tools/ never ships.

const GRAYSCALE: String = "--grayscale"
const REDUCED_MOTION: String = "--reduced-motion"
const TEXT_SIZE: String = "--text-size"
## Above PostProcess.LAYER and every layer the game makes.
const LAYER: int = 128
const SAVE_FILE: String = "tool_settings.cfg"
const PROFILES: String = "res://tools/walk_profile.gd"
const SHADER: String = """
shader_type canvas_item;
uniform sampler2D screen: hint_screen_texture, filter_linear;
void fragment() {
	vec3 seen = texture(screen, SCREEN_UV).rgb;
	COLOR = vec4(vec3(dot(seen, vec3(0.299, 0.587, 0.114))), 1.0);
}
"""


## True when the tool was given any of the flags.
static func any(args: PackedStringArray) -> bool:
	return args.has(GRAYSCALE) or args.has(REDUCED_MOTION) or args.has(TEXT_SIZE)


## The text size asked for, or -1 when none was.
static func text_size(args: PackedStringArray) -> int:
	var at: int = args.find(TEXT_SIZE)
	if at < 0 or at + 1 >= args.size():
		return -1
	return clampi(args[at + 1].to_int(), 0, 2)


## Applies the flags in args to the running tool, before the app is made, and says what it
## applied.
static func apply(root: Window, args: PackedStringArray) -> String:
	if not any(args):
		return "display flags: none"
	var settings: Node = root.get_node("Settings")
	var profiles: GDScript = load(PROFILES)
	var folder: String = profiles.call("folder", "playtest", args)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	settings.call("save_to", folder + SAVE_FILE)
	var reduced: bool = args.has(REDUCED_MOTION)
	if reduced:
		settings.call("set_value", "reduced_motion", true)
	var size: int = text_size(args)
	if size >= 0:
		settings.call("set_value", "text_size", size)
	var gray: bool = args.has(GRAYSCALE)
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
	pass_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(pass_rect)
	return layer
