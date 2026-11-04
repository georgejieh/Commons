class_name CheatSheet
extends PanelContainer
## The always-available rules card (P3B.5): every hand type with a small example, the
## rule changes active now, and the current rank order, low to high. While open it
## redraws on every run event, so a changed rule shows the frame it changes.

const TYPES: Array[String] = [
	"single",
	"pair",
	"trio",
	"trio_single",
	"trio_pair",
	"straight",
	"pair_chain",
	"airplane",
	"airplane_singles",
	"airplane_pairs",
	"four_two_singles",
	"four_two_pairs",
	"bomb",
	"rocket",
]

var _controller: RunController
var _types: Label = Label.new()
var _active: Label = Label.new()
var _order: Label = Label.new()


func _ready() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	for label: Label in [_types, _active, _order]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(620, 0)
		box.add_child(label)
	add_child(box)
	visible = false


func toggle(controller: RunController) -> void:
	if _controller == null:
		_controller = controller
		_controller.event_emitted.connect(func(_event: RunEvent) -> void: refresh())
	visible = not visible
	refresh()


func refresh() -> void:
	if not visible or _controller == null:
		return
	var lines: PackedStringArray = [tr("cheat.title")]
	for type: String in TYPES:
		lines.append("%s  %s" % [tr("pattern." + type), tr("cheat.example." + type)])
	_types.text = "\n".join(lines)
	var active: PackedStringArray = [tr("cheat.active")]
	for modifier_id: String in _controller.active_modifier_ids():
		active.append(
			(
				"%s: %s"
				% [tr("modifier.%s.name" % modifier_id), _controller.modifier_text(modifier_id)]
			)
		)
	if active.size() == 1:
		active.append(tr("cheat.none"))
	_active.text = "\n".join(active)
	_order.text = tr("cheat.order").format({"order": " < ".join(_rank_order())})


func rank_order_text() -> String:
	return _order.text


func _rank_order() -> PackedStringArray:
	var rank_map: PackedByteArray = _controller.player_table().rank_map
	var ranks: Array[int] = []
	for rank: int in Ranks.COUNT:
		ranks.append(rank)
	ranks.sort_custom(func(a: int, b: int) -> bool: return rank_map[a] < rank_map[b])
	var glyphs: PackedStringArray = []
	for rank: int in ranks:
		glyphs.append(tr(CardView.RANK_KEYS[rank]))
	return glyphs
