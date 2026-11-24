class_name DebuffStrip
extends PanelContainer
## The rules in force this round, on a paper slip under the right seat (ADR 0034, rule
## 6), so a rule that changes play is always in view, not only on the Rules sheet: first
## the round's wild ranks on one line (ADR 0029), then the round's debuffs, then a
## Reform's rule that changes play for the whole table. A Cadre is never here: it works
## for the player's household alone (ADR 0039), and its card is on the board. Hidden while
## none applies.
##
## The slip keeps to a room the table gives it and steps down one form at a time until
## it fits (rule 7): in full; by name, with a line that points to the Rules sheet; by name
## with the type fitted down, never under Standard; and, when the table allows it,
## counted. It never shows some rules in full and others by name.

## The rules in force were read again, so the table can lay out the slip's column.
signal shown

enum Form { FULL, NAMED, FITTED, COUNTED }

const NAME_HEX: String = "9e1b16"
const FONT_SIZE: int = 20
const HEAD_SIZE: int = 16
## Room inside the paper's printed border.
const PADDING: int = 22
## Between names in the named forms.
const SEPARATOR: String = "  ·  "

## The round's wild ranks as the table's events have named them (ADR 0029), the strip's
## first line.
var wild_ranks: Array[int] = []
## The most the slip may stand, paper included; the table sets it from its column.
var room: float = INF
## Whether the slip may count its rules when naming them does not fit.
var allow_count: bool = true

var _lines: KeywordText = KeywordText.new()
var _form: Form = Form.FULL
var _yours: Array[Dictionary] = []
var _everyone: Array[Dictionary] = []


func _init() -> void:
	add_theme_stylebox_override("panel", ScreenKit.paper_style(PADDING))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.bbcode_enabled = true
	_lines.fit_content = true
	_lines.scroll_active = false
	_lines.mouse_filter = Control.MOUSE_FILTER_PASS
	_set_type(TextSize.px(FONT_SIZE))
	_lines.add_theme_font_override("bold_font", ScreenKit.DISPLAY_BOLD)
	_lines.add_theme_color_override("default_color", ScreenKit.INK)
	add_child(_lines)
	visible = false


func show_debuffs(controller: RunController) -> void:
	_yours.clear()
	_everyone = _table_rules(controller)
	for modifier_id: String in controller.active_debuff_ids():
		_yours.append(_rule(controller, modifier_id))
	refit()
	shown.emit()


## Lays the rules out again in the first form that fits the room now.
func refit() -> void:
	_form = Form.FULL
	_set_type(TextSize.px(FONT_SIZE))
	_lines.text = _full()
	visible = not _lines.text.is_empty()
	if not visible:
		size = Vector2(size.x, 0.0)
		return
	if _measure() > room and _named_count() > 0:
		_lines.text = _by_name()
		_form = Form.NAMED
		if _measure() > room:
			_form = Form.FITTED
			_fit_type()
		if _measure() > room and allow_count:
			_set_type(TextSize.px(FONT_SIZE))
			_lines.text = _counted()
			_form = Form.COUNTED
			_fit_type()
	# The lines' cached minimum can still be the full form's; thrown out by hand, and the
	# paper sorted again, so the lines' box never stands taller than the slip.
	_lines.update_minimum_size()
	update_minimum_size()
	size = Vector2(size.x, _measure() if visible else 0.0)
	queue_sort()


## True when the slip as laid out stands within its room.
func fits() -> bool:
	return not visible or _measure() <= room + 0.5


func form() -> Form:
	return _form


## True while the slip names or counts its rules rather than showing them in full.
func is_named() -> bool:
	return _form != Form.FULL


## How many rules the named forms name: the debuffs and the table's rules.
func _named_count() -> int:
	return _yours.size() + _everyone.size()


func _fit_type() -> void:
	var fits_at: Callable = func(font_size: int) -> bool:
		_set_type(font_size)
		return _measure() <= room
	_set_type(TextSize.fit(FONT_SIZE, FONT_SIZE, fits_at))


## Every rule in full: the wild ranks' line, then each group under its head.
func _full() -> String:
	var rows: PackedStringArray = _wild_row()
	for group: Array in [["table.debuffs", _yours], ["table.rules_everyone", _everyone]]:
		var rules: Array[Dictionary] = []
		rules.assign(group[1])
		if rules.is_empty():
			continue
		rows.append(_head(group[0]))
		for rule: Dictionary in rules:
			var row: String = "%s  %s" % [_name(rule["name"]), rule["rule"]]
			# Appeal lifts this round's debuff: it stays listed, struck through (ADR 0021).
			if bool(rule["lifted"]):
				row = "[s]%s[/s]  %s" % [row, _escape(tr("table.debuff_lifted"))]
			rows.append(row)
	return "\n".join(rows)


## The debuffs and the table's rules by name, each group's head beside its names, a
## lifted debuff struck through, and the line that points to the Rules sheet.
func _by_name() -> String:
	var rows: PackedStringArray = _wild_row()
	for group: Array in [["table.debuffs", _yours], ["table.rules_everyone", _everyone]]:
		var rules: Array[Dictionary] = []
		rules.assign(group[1])
		if rules.is_empty():
			continue
		var names: PackedStringArray = []
		for rule: Dictionary in rules:
			var name: String = _name(rule["name"])
			names.append("[s]%s[/s]" % name if bool(rule["lifted"]) else name)
		rows.append("%s  %s" % [_head(group[0]), SEPARATOR.join(names)])
	var one: bool = _named_count() == 1
	rows.append(_escape(tr("table.rules_named.one" if one else "table.rules_named")))
	return "\n".join(rows)


## The wild ranks' line and how many rules are in force, with the pointer.
func _counted() -> String:
	var rows: PackedStringArray = _wild_row()
	var count: int = _named_count()
	if count == 1:
		rows.append(_escape(tr("table.rules_counted.one")))
	else:
		rows.append(_escape(tr("table.rules_counted").format({"count": count})))
	return "\n".join(rows)


## The round's wild ranks on one line, "Sevens and Queens are wild", or no row with none.
## What a wild card may do is on the Rules sheet.
func _wild_row() -> PackedStringArray:
	var rows: PackedStringArray = []
	if not wild_ranks.is_empty():
		var named: String = _escape(ReadingText.wild_line(wild_ranks))
		var whose: String = _escape(tr("wild.strip"))
		rows.append("%s  %s" % [_name(named), whose])
	return rows


## Each held Reform that changes play for every seat, such as Industrialization.
func _table_rules(controller: RunController) -> Array[Dictionary]:
	var rules: Array[Dictionary] = []
	for reform_id: String in controller.table_rule_reforms():
		var name: String = _escape(controller.reform_name(reform_id))
		var text: String = Keywords.mark(controller.reform_text(reform_id))
		rules.append({"name": name, "rule": text, "lifted": false})
	return rules


func _rule(controller: RunController, modifier_id: String) -> Dictionary:
	return {
		"name": _escape(controller.modifier_name(modifier_id)),
		"rule": Keywords.mark(controller.modifier_text(modifier_id)),
		"lifted": modifier_id == controller.lifted_debuff(),
	}


func _head(key: String) -> String:
	return "[font_size=%d]%s[/font_size]" % [TextSize.px(HEAD_SIZE), tr(key).to_upper()]


func _name(name: String) -> String:
	return "[b][color=#%s]%s[/color][/b]" % [NAME_HEX, name]


func _set_type(font_size: int) -> void:
	var type_px: int = maxi(font_size, TextSize.least(FONT_SIZE))
	_lines.add_theme_font_size_override("normal_font_size", type_px)
	_lines.add_theme_font_size_override("bold_font_size", type_px)


## How tall the slip stands with its text at its width, paper included.
func _measure() -> float:
	var edges: Vector2 = get_theme_stylebox("panel").get_minimum_size()
	_lines.size = Vector2(maxf(size.x - edges.x, 1.0), _lines.size.y)
	return _lines.get_content_height() + edges.y


## Strikes the lifted debuff off the strip now, pressed like ink when animate is set.
func strike(controller: RunController, animate: bool) -> void:
	show_debuffs(controller)
	if animate:
		UiMotion.stamp(self)


## How tall the slip stands now, paper included, or 0 while hidden.
func standing() -> float:
	return _measure() if visible else 0.0


## The type the rules are set in now.
func type_size() -> int:
	return _lines.get_theme_font_size("normal_font_size")


## The plain text shown, for tests.
func shown_text() -> String:
	return _lines.get_parsed_text() if visible else ""


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
