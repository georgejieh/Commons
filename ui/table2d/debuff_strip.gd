class_name DebuffStrip
extends PanelContainer
## The rules in force this round, on a paper slip under the Cadre board, so a rule
## that changes play is always in view, not only on the rules sheet: first the debuffs
## that bind only the player, then anything, debuff or Cadre, that changes play for the
## whole table. Hidden while neither applies.

const NAME_HEX: String = "9e1b16"
const FONT_SIZE: int = 20
const HEAD_SIZE: int = 14
## Room inside the paper's printed border.
const PADDING: int = 22

var _lines: KeywordText = KeywordText.new()


func _init() -> void:
	add_theme_stylebox_override("panel", ScreenKit.paper_style(PADDING))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.bbcode_enabled = true
	_lines.fit_content = true
	_lines.scroll_active = false
	_lines.mouse_filter = Control.MOUSE_FILTER_PASS
	_lines.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_lines.add_theme_font_size_override("bold_font_size", FONT_SIZE)
	_lines.add_theme_font_override("bold_font", ScreenKit.DISPLAY_BOLD)
	_lines.add_theme_color_override("default_color", ScreenKit.INK)
	add_child(_lines)
	visible = false


func show_debuffs(controller: RunController) -> void:
	var yours: PackedStringArray = []
	var everyone: PackedStringArray = []
	var ids: Array[String] = controller.active_debuff_ids()
	for cadre_id: String in controller.state_copy().inventory.cadres:
		if controller.is_table_wide(cadre_id):
			ids.append(cadre_id)
	for modifier_id: String in ids:
		var name: String = _escape(tr("modifier.%s.name" % modifier_id))
		var rule: String = Keywords.mark(controller.modifier_text(modifier_id))
		var row: String = "[b][color=#%s]%s[/color][/b]  %s" % [NAME_HEX, name, rule]
		if controller.is_table_wide(modifier_id):
			everyone.append(row)
		else:
			yours.append(row)
	var rows: PackedStringArray = []
	_add_group(rows, "table.debuffs", yours)
	_add_group(rows, "table.rules_everyone", everyone)
	_lines.text = "\n".join(rows)
	visible = not rows.is_empty()


func _add_group(rows: PackedStringArray, head_key: String, group: PackedStringArray) -> void:
	if group.is_empty():
		return
	rows.append("[font_size=%d]%s[/font_size]" % [HEAD_SIZE, tr(head_key).to_upper()])
	rows.append_array(group)


## The plain text shown, for tests.
func shown_text() -> String:
	return _lines.get_parsed_text() if visible else ""


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
