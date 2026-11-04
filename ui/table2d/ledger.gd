class_name Ledger
extends VBoxContainer
## The work-point ledger: one row per scored play, newest at the bottom. Rows are made
## once and reused, so scoring a play instances nothing.

const MAX_ROWS: int = 9
const INK: Color = Color("1e1a16")
const STAMP: Color = Color("b02a17")

var _pending_type: String = ""
var _texts: PackedStringArray = []
var _labels: Array[Label] = []


func _ready() -> void:
	var title: Label = Label.new()
	title.text = tr("ledger.title")
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_font_override("font", ScreenKit.TYPEWRITER_BOLD)
	title.add_theme_color_override("font_color", INK)
	add_child(title)
	for _index: int in MAX_ROWS:
		var row: Label = Label.new()
		row.add_theme_font_size_override("font_size", 18)
		row.add_theme_font_override("font", ScreenKit.TYPEWRITER)
		row.add_theme_color_override("font_color", STAMP)
		add_child(row)
		_labels.append(row)


## The next row's hand type, from the play event that comes before its score.
func set_pending(type_text: String) -> void:
	_pending_type = type_text


func add_row(who: String, total: float) -> void:
	_texts.append(
		tr("ledger.row").format({"who": who, "type": _pending_type, "total": Strings.score(total)})
	)
	if _texts.size() > MAX_ROWS:
		_texts.remove_at(0)
	_show()


func clear_rows() -> void:
	_texts.clear()
	_show()


func row_texts() -> PackedStringArray:
	return _texts


func _show() -> void:
	for index: int in _labels.size():
		_labels[index].text = _texts[index] if index < _texts.size() else ""
