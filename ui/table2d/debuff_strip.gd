class_name DebuffStrip
extends PanelContainer
## The debuffs in force this round, on a paper slip under the Cadre board, so a rule
## that changes play is always in view, not only on the rules sheet. Hidden while no
## debuff applies.

const NAME_HEX: String = "9e1b16"
const FONT_SIZE: int = 20
## Room inside the paper's printed border.
const PADDING: int = 22

var _lines: RichTextLabel = RichTextLabel.new()


func _init() -> void:
	add_theme_stylebox_override("panel", ScreenKit.paper_style(PADDING))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.bbcode_enabled = true
	_lines.fit_content = true
	_lines.scroll_active = false
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_lines.add_theme_font_size_override("bold_font_size", FONT_SIZE)
	_lines.add_theme_font_override("bold_font", ScreenKit.DISPLAY_BOLD)
	_lines.add_theme_color_override("default_color", ScreenKit.INK)
	add_child(_lines)
	visible = false


func show_debuffs(controller: RunController) -> void:
	var rows: PackedStringArray = []
	for debuff_id: String in controller.active_debuff_ids():
		var name: String = _escape(tr("modifier.%s.name" % debuff_id))
		var rule: String = _escape(controller.modifier_text(debuff_id))
		rows.append("[b][color=#%s]%s[/color][/b]  %s" % [NAME_HEX, name, rule])
	_lines.text = "\n".join(rows)
	visible = not rows.is_empty()


## The plain text shown, for tests.
func shown_text() -> String:
	return _lines.get_parsed_text() if visible else ""


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
