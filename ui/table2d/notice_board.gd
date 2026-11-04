class_name NoticeBoard
extends HBoxContainer
## The player's Cadres as portrait cards pinned in slot order. Slots are made once.

const PAPER: Color = Color("f6edd9")
const INK: Color = Color("1e1a16")

var _labels: Array[Label] = []


## Makes one slot per Cadre the player can hold.
func setup(slots: int) -> void:
	add_theme_constant_override("separation", 14)
	for _index: int in slots:
		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(108, 130)
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = PAPER
		style.set_border_width_all(2)
		style.border_color = INK
		card.add_theme_stylebox_override("panel", style)
		var label: Label = Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", INK)
		label.add_theme_font_size_override("font_size", 17)
		card.add_child(label)
		add_child(card)
		_labels.append(label)


func show_cadres(cadre_ids: Array[String]) -> void:
	for index: int in _labels.size():
		var held: bool = index < cadre_ids.size()
		_labels[index].text = (
			tr("modifier.%s.name" % cadre_ids[index]) if held else tr("board.empty")
		)
		_labels[index].modulate.a = 1.0 if held else 0.45
