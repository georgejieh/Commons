class_name EnvelopeDetail
extends PanelContainer
## The explanation under an open envelope's papers (ADR 0021), for papers that do not
## print their own rules: the pointed item's name over its full rules with their keywords
## marked, and each keyword's meaning beside them in smaller type. It only explains:
## clicks pass through it.

const SIZE: Vector2 = Vector2(1040, 150)
const RULE_WIDTH: float = 560.0
const MEANING_WIDTH: float = 440.0
const TITLE_SIZE: int = 24
const RULE_SIZE: int = 19
const MEANING_SIZE: int = 16
## Inside the paper's printed border, which ends 17 px in.
const PADDING: int = 22

## The rules of what is explained.
var rule_text: RichTextLabel = RichTextLabel.new()
var _title: Label = ScreenKit.label("", TITLE_SIZE)
var _meanings: VBoxContainer = VBoxContainer.new()


func _init() -> void:
	add_theme_stylebox_override("panel", ScreenKit.paper_style(PADDING))
	custom_minimum_size = SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var left: VBoxContainer = VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	_title.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
	left.add_child(_title)
	rule_text.bbcode_enabled = true
	rule_text.fit_content = true
	rule_text.scroll_active = false
	rule_text.custom_minimum_size = Vector2(RULE_WIDTH, 0)
	rule_text.add_theme_font_size_override("normal_font_size", TextSize.px(RULE_SIZE))
	rule_text.add_theme_color_override("default_color", ScreenKit.INK)
	left.add_child(rule_text)
	_meanings.custom_minimum_size = Vector2(MEANING_WIDTH, 0)
	_meanings.add_theme_constant_override("separation", 2)
	add_child(ScreenKit.row([left, _meanings], 24))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for node: Node in find_children("*", "Control", true, false):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


## Explains an item: its name over its rules, and what each keyword in them means.
func explain(title: String, rule: String) -> void:
	_title.text = title
	rule_text.text = Keywords.mark(rule)
	ScreenKit.clear(_meanings)
	for id: String in Keywords.found(rule):
		var meaning: Label = ScreenKit.label(
			Keywords.meaning(id), MEANING_SIZE, ScreenKit.FAINT_INK
		)
		meaning.custom_minimum_size = Vector2(MEANING_WIDTH, 0)
		meaning.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_meanings.add_child(meaning)


func shown_title() -> String:
	return _title.text


## The reason no paper in shelf's open envelope can be kept, when every one is refused
## for the same reason; empty when any can be kept or the reasons differ.
static func shared_refusal(shelf: EnvelopeShelf) -> String:
	var shared: String = ""
	for index: int in shelf.count():
		var why: String = shelf.refusal_key(index)
		if why.is_empty() or (not shared.is_empty() and why != shared):
			return ""
		shared = why
	return shared


## True when some paper in shelf's open envelope does not print its own rules, as a
## Campaign's leaflet and a plot card do not; a Directive's document says everything.
static func needed(shelf: EnvelopeShelf) -> bool:
	for index: int in shelf.count():
		if shelf.kind(index) != EnvelopeShelf.KIND_DIRECTIVE:
			return true
	return false
