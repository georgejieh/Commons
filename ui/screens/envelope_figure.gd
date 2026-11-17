class_name EnvelopeFigure
extends Control
## The envelope itself while it is opened (ADR 0021): drawn as EnvelopePaper has it, at
## whatever size it is moved to, and opened as far as opened says, from 0 to 1.

var wrapping: int = EnvelopePaper.STRING_TIE
var which: int = 0
var opened: float = 0.0:
	set(value):
		opened = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	EnvelopePaper.draw(self, Rect2(Vector2.ZERO, size), wrapping, BowlGrime.wear(), which, opened)
