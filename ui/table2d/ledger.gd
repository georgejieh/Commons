class_name Ledger
extends VBoxContainer
## The work-point ledger: one row per scored play, newest at the bottom. Rows are made
## once and reused, so scoring a play instances nothing. The newest score counts up
## from zero as its row is stamped in (P3B.6).

const MAX_ROWS: int = 9
## Rows wrap inside the ledger's paper.
const ROW_WIDTH: float = 270.0
const INK: Color = Color("1e1a16")
const STAMP: Color = Color("b02a17")

var _pending_type: String = ""
var _texts: PackedStringArray = []
var _labels: Array[Label] = []
var _counting: Tween = null


func _ready() -> void:
	var title: Label = Label.new()
	title.text = tr("ledger.title")
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_font_override("font", ScreenKit.TYPEWRITER_BOLD)
	title.add_theme_color_override("font_color", INK)
	add_child(title)
	for _index: int in MAX_ROWS:
		var row: Label = Label.new()
		row.add_theme_font_size_override("font_size", 20)
		row.add_theme_font_override("font", ScreenKit.TYPEWRITER)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(ROW_WIDTH, 0)
		row.add_theme_color_override("font_color", INK)
		row.add_theme_constant_override("line_spacing", -2)
		add_child(row)
		_labels.append(row)


## The next row's hand type, from the play event that comes before its score.
func set_pending(type_text: String) -> void:
	_pending_type = type_text


func add_row(who: String, total: float) -> void:
	# Two lines per entry: who and the score, then the hand type indented beneath.
	var type_text: String = _pending_type
	_texts.append(_row_text(who, total, type_text))
	if _texts.size() > MAX_ROWS:
		_texts.remove_at(0)
	_show()
	var newest: Label = _labels[mini(_texts.size(), _labels.size()) - 1]
	UiMotion.stamp(newest)
	_counting = UiMotion.count(
		newest, 0.0, total, func(shown: float) -> String: return _row_text(who, shown, type_text)
	)


func clear_rows() -> void:
	_texts.clear()
	_show()


func row_texts() -> PackedStringArray:
	return _texts


## Whether the newest score is still counting up.
func is_counting() -> bool:
	return _counting != null and _counting.is_running()


func _row_text(who: String, total: float, type_text: String) -> String:
	var head: String = tr("ledger.row").format({"who": who, "total": Strings.score(total)})
	return "%s\n  %s" % [head, type_text]


func _show() -> void:
	# A count still rolling would write over a row that has moved up.
	if _counting != null and _counting.is_valid():
		_counting.kill()
	_counting = null
	for index: int in _labels.size():
		_labels[index].text = _texts[index] if index < _texts.size() else ""
