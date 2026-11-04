class_name TableAtmosphere
extends Control
## The dark room around the table: near-black outside one weak lamp's pool of light,
## and faint eyes watching from beyond it. It sits over the table surface and under
## the cards, seats and controls, so it never covers anything the player reads. The
## meters drive it: the pool shrinks with the worse meter, and more eyes show as
## Denunciation rises, though some are always there.

const LAMP_SHADER: Shader = preload("res://shaders/lamp_light.gdshader")
const WATCHERS_SHADER: Shader = preload("res://shaders/watchers.gdshader")
## How many watching eyes show with Denunciation at zero, and at its worst.
const WATCHERS_BASE: float = 0.28
const WATCHERS_FULL: float = 0.9

var _lamp: ColorRect = ColorRect.new()
var _watchers: TextureRect = ScreenKit.cover(ScreenKit.ART.watchers)
var _lamp_material: ShaderMaterial = ShaderMaterial.new()
var _eyes_material: ShaderMaterial = ShaderMaterial.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lamp_material.shader = LAMP_SHADER
	_lamp.material = _lamp_material
	_lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lamp.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_lamp)
	_eyes_material.shader = WATCHERS_SHADER
	_watchers.material = _eyes_material
	add_child(_watchers)
	show_meters(0, 0)


## Meters run 0 to 100.
func show_meters(famine: int, denunciation: int) -> void:
	_lamp_material.set_shader_parameter("dread", maxi(famine, denunciation) / 100.0)
	var watching: float = lerpf(WATCHERS_BASE, WATCHERS_FULL, denunciation / 100.0)
	_eyes_material.set_shader_parameter("presence", watching)
