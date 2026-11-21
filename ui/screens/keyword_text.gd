class_name KeywordText
extends RichTextLabel
## Rules text whose keywords explain themselves: set_rule() marks them, and resting the
## pointer on one opens its meaning on a slip the pointer can move onto (KeywordTips).

## The keywords whose slips are open under this text, when it stands on one of them.
var chain: PackedStringArray = []


func _init() -> void:
	bbcode_enabled = true
	fit_content = true
	scroll_active = false
	# A marked word is a link; the text draws its own underline and ink.
	meta_underlined = false
	# Words only answer the pointer when the text takes the mouse.
	mouse_filter = Control.MOUSE_FILTER_PASS
	meta_hover_started.connect(_on_word)
	meta_hover_ended.connect(_off_word)


## Shows plain rules text with its keywords marked, but for those in skip.
func set_rule(plain: String, skip: PackedStringArray = []) -> void:
	text = Keywords.mark(plain, skip)


func _on_word(meta: Variant) -> void:
	if is_inside_tree():
		KeywordTips.of(self).ask(self, str(meta))


func _off_word(meta: Variant) -> void:
	if is_inside_tree():
		KeywordTips.of(self).left(self, str(meta))
