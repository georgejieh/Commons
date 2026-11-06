class_name PostProcess
extends CanvasLayer
## The one full-screen pass over every screen (P3B.7), drawn above the UI. The quality
## setting turns it off. At the table the dread layers (P3B.12) write its parameters;
## they never change what the player reads, only how the paper looks.

const SHADER: Shader = preload("res://shaders/post_process.gdshader")
const LAYER: int = 100

var _rect: ColorRect = ColorRect.new()
var _material: ShaderMaterial = ShaderMaterial.new()


func _ready() -> void:
	layer = LAYER
	_material.shader = SHADER
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)
	Settings.changed.connect(_on_setting)
	_apply_quality()


## The pass's material, for the dread layers.
func material() -> ShaderMaterial:
	return _material


func is_on() -> bool:
	return _rect.visible


func _on_setting(key: String) -> void:
	if key == "post_process":
		_apply_quality()


func _apply_quality() -> void:
	_rect.visible = bool(Settings.value("post_process"))
