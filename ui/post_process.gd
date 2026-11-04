class_name PostProcess
extends CanvasLayer
## The one full-screen pass over every screen (P3B.7), drawn above the UI. The quality
## setting turns it off. set_dread() eases the decay value from the meters; it never
## changes what the player reads, only how the paper looks.

const SHADER: Shader = preload("res://shaders/post_process.gdshader")
const LAYER: int = 100
## How fast dread eases toward its target, per second.
const EASE_RATE: float = 0.4

var _rect: ColorRect = ColorRect.new()
var _material: ShaderMaterial = ShaderMaterial.new()
var _dread: float = 0.0
var _target: float = 0.0


func _ready() -> void:
	layer = LAYER
	_material.shader = SHADER
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)
	Settings.changed.connect(_on_setting)
	_apply_quality()


## Dread from 0 to 1, eased over a few seconds.
func set_dread(value: float) -> void:
	_target = clampf(value, 0.0, 1.0)


func is_on() -> bool:
	return _rect.visible


func _process(delta: float) -> void:
	_dread = move_toward(_dread, _target, EASE_RATE * delta)
	_material.set_shader_parameter("dread", _dread)


func _on_setting(key: String) -> void:
	if key == "post_process":
		_apply_quality()


func _apply_quality() -> void:
	_rect.visible = bool(Settings.value("post_process"))
