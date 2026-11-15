class_name Scrim
extends ColorRect
## The dim laid over a page behind whatever asks the player something: the rank picker
## and an opened envelope. It covers the whole screen and takes every click, so nothing on
## the page behind can be pressed, and nothing behind shows through around the question.

const DIM: Color = Color(0.03, 0.02, 0.02, 0.74)


func _init() -> void:
	color = DIM
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
