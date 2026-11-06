class_name TableAtmosphere
extends Control
## The dark room around the table: near-black outside one weak lamp's pool of light,
## and faint eyes watching from beyond it. It sits over the table surface and under
## the cards, seats and controls, so it never covers anything the player reads. The
## dread layers (P3B.12) drive its materials: the pool shrinks as Famine rises, and more
## eyes show as Denunciation rises, though some are always there.

const LAMP_SHADER: Shader = preload("res://shaders/lamp_light.gdshader")
const WATCHERS_SHADER: Shader = preload("res://shaders/watchers.gdshader")

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


func lamp_material() -> ShaderMaterial:
	return _lamp_material


func eyes_material() -> ShaderMaterial:
	return _eyes_material
