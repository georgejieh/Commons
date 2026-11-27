class_name EnvelopeFigure
extends Control
## The envelope itself while it is opened (ADR 0021): drawn as EnvelopePaper has it, at
## whatever size it is moved to, and opened as far as opened says, from 0 to 1.

## How the envelope is wrapped, which decides how it is drawn and how it opens.
var wrapping: EnvelopeDef.Wrapping = EnvelopeDef.Wrapping.STRING_TIE
## Which envelope this is, so each keeps its own stains.
var which: int = 0
## How far open the envelope is, from 0 shut to 1 open; setting it redraws.
var opened: float = 0.0:
	set(value):
		opened = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	EnvelopePaper.draw(self, Rect2(Vector2.ZERO, size), wrapping, BowlGrime.wear(), which, opened)
