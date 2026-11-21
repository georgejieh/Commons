class_name KeywordSlip
extends PanelContainer
## One keyword's meaning on a paper slip the pointer can move onto (KeywordTips). The
## words inside explain themselves in turn, but never the keyword itself nor any whose
## slip is already open under this one, so a chain of slips always ends.

## Inside the paper's printed border, which ends 17 px in.
const PADDING: int = 22

## The keyword explained, and the text it was opened from.
var id: String = ""
var source: Control = null
## True while the pointer is on the word that opened this slip.
var word_held: bool = true
## Seconds since the pointer was last on the word, this slip or a slip opened from it.
var idle: float = 0.0
## Where the pointer was when the slip was asked for, and whether it has been stood yet.
var asked_at: Vector2 = Vector2.ZERO
var placed: bool = false

var _rule: KeywordText = KeywordText.new()


func _init() -> void:
	add_theme_stylebox_override("panel", ScreenKit.paper_style(PADDING))
	# The pointer rests on the paper, so nothing under it is hovered through it.
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rule.custom_minimum_size = Vector2(Keywords.SLIP_WIDTH, 0)
	_rule.add_theme_font_size_override("normal_font_size", TextSize.px(Keywords.SLIP_SIZE))
	_rule.add_theme_color_override("default_color", ScreenKit.INK)
	add_child(_rule)
	modulate.a = 0.0


## Shows keyword_id's meaning. chain names the keywords open under this slip, itself
## included; none of them is marked in its text.
func explain(keyword_id: String, chain: PackedStringArray) -> void:
	id = keyword_id
	_rule.chain = chain
	_rule.set_rule(Keywords.meaning(keyword_id), chain)


## The text shown, as BBCode, and the text control itself, for tests.
func rule_text() -> String:
	return _rule.text


func rule() -> KeywordText:
	return _rule
