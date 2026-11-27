class_name KeywordText
extends RichTextLabel
## Rules text whose keywords explain themselves: set_rule() marks them, and hovering
## one shows its meaning on a slip that wraps instead of running off the screen.


func _init() -> void:
	bbcode_enabled = true
	fit_content = true
	scroll_active = false
	# Hints only show when the text takes the mouse.
	mouse_filter = Control.MOUSE_FILTER_PASS


## Shows plain rules text with its keywords marked.
func set_rule(plain: String) -> void:
	text = Keywords.mark(plain)


func _make_custom_tooltip(for_text: String) -> Object:
	return Keywords.slip(for_text)
