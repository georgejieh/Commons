class_name SetIntroScreen
extends Control
## Before a Set: its type, its target and reward, and the debuff ladder drawn for it,
## one card per round, with round 1 always clean.


func open(app: DemoApp) -> void:
	var controller: RunController = app.controller
	var state: RunState = controller.state_copy()
	var column: VBoxContainer = ScreenKit.page(self)
	column.add_child(
		ScreenKit.label(
			tr("intro.where").format({"year": state.year, "set": state.set_index + 1}), 26
		)
	)
	column.add_child(ScreenKit.label(tr("set.type.%d" % state.set_type), 88, ScreenKit.RED))
	column.add_child(
		ScreenKit.label(
			tr("intro.target").format(
				{"target": Strings.score(controller.target()), "rounds": app.max_rounds()}
			),
			34
		)
	)
	column.add_child(ScreenKit.label(tr("intro.ladder"), 30))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var ladder: Array[String] = controller.ladder()
	for round_index: int in ladder.size():
		row.add_child(_step(controller, round_index, ladder[round_index]))
	column.add_child(row)
	var begin: Button = ScreenKit.button(tr("intro.begin"), ScreenKit.RED)
	begin.pressed.connect(func() -> void: app.show_screen(app.table_id(), true))
	column.add_child(begin)
	begin.grab_focus()


func _step(controller: RunController, round_index: int, debuff_id: String) -> Control:
	var card: VBoxContainer = ScreenKit.card(Vector2(320, 260))
	card.add_child(ScreenKit.label(tr("intro.round").format({"round": round_index + 1}), 24))
	if debuff_id.is_empty():
		card.add_child(ScreenKit.label(tr("intro.clean"), 30))
		card.add_child(ScreenKit.label(tr("intro.clean_text"), 20))
	else:
		card.add_child(ScreenKit.label(tr("modifier.%s.name" % debuff_id), 30, ScreenKit.RED))
		card.add_child(ScreenKit.label(controller.modifier_text(debuff_id), 20))
	return ScreenKit.card_panel(card)
