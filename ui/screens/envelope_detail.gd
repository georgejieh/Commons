class_name EnvelopeDetail
extends PanelContainer
## The explanation under an open envelope's papers (ADR 0021): the pointed item's name
## over its full rules with their keywords marked, each keyword's meaning beside them in
## smaller type, and, after a first cancel, the line asking for a second. It only
## explains: clicks pass through it.

const SIZE: Vector2 = Vector2(1040, 150)
const RULE_WIDTH: float = 560.0
const MEANING_WIDTH: float = 440.0
const TITLE_SIZE: int = 24
const RULE_SIZE: int = 19
const MEANING_SIZE: int = 16
const PADDING: int = 16

var _title: Label = ScreenKit.label("", TITLE_SIZE)
var _rule: RichTextLabel = RichTextLabel.new()
var _meanings: VBoxContainer = VBoxContainer.new()
var _hint: Label = ScreenKit.label("", MEANING_SIZE, ScreenKit.RED)


func _init() -> void:
	add_theme_stylebox_override("panel", ScreenKit.paper_style(PADDING))
	custom_minimum_size = SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var left: VBoxContainer = VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	_title.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
	left.add_child(_title)
	_rule.bbcode_enabled = true
	_rule.fit_content = true
	_rule.scroll_active = false
	_rule.custom_minimum_size = Vector2(RULE_WIDTH, 0)
	_rule.add_theme_font_size_override("normal_font_size", TextSize.px(RULE_SIZE))
	_rule.add_theme_color_override("default_color", ScreenKit.INK)
	left.add_child(_rule)
	_hint.text = TranslationServer.translate("envelope.nothing.confirm")
	_hint.visible = false
	left.add_child(_hint)
	_meanings.custom_minimum_size = Vector2(MEANING_WIDTH, 0)
	_meanings.add_theme_constant_override("separation", 2)
	add_child(ScreenKit.row([left, _meanings], 24))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for node: Node in find_children("*", "Control", true, false):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


## Explains an item: its name over its rules, and what each keyword in them means.
func explain(title: String, rule: String) -> void:
	_hint.visible = false
	_title.text = title
	_rule.text = Keywords.mark(rule)
	for child: Node in _meanings.get_children():
		_meanings.remove_child(child)
		child.queue_free()
	for id: String in Keywords.found(rule):
		var meaning: Label = ScreenKit.label(Keywords.meaning(id), MEANING_SIZE, Keywords.SOFT)
		meaning.custom_minimum_size = Vector2(MEANING_WIDTH, 0)
		meaning.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_meanings.add_child(meaning)


## Shows or hides the line asking for a second cancel.
func ask_to_confirm(on: bool) -> void:
	_hint.visible = on


func asks_to_confirm() -> bool:
	return _hint.visible


func shown_title() -> String:
	return _title.text
