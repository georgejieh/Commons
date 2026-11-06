class_name SetIntroScreen
extends Control
## Before a Set: its type, its target and reward, and the debuff ladder drawn for it,
## one card per round, with round 1 always clean.


func open(app: DemoApp) -> void:
	var controller: RunController = app.controller
	var state: RunState = controller.state_copy()
	var column: VBoxContainer = ScreenKit.page(self, ScreenKit.ART.notice_wall)
	var where: String = tr("intro.where").format(
		{"year": state.year, "set": state.set_index + 1, "sets": app.sets_per_year()}
	)
	column.add_child(ScreenKit.header(where, tr("set.type.%d" % state.set_type)))
	var target: String = tr("intro.target").format(
		{"target": Strings.score(controller.target()), "rounds": app.max_rounds()}
	)
	column.add_child(ScreenKit.styled(target, CommonsTheme.TITLE))
	if not controller.boss().is_empty():
		column.add_child(_boss_line(controller))
	column.add_child(ScreenKit.eyebrow(tr("intro.ladder")))
	var steps: Array[Control] = []
	var ladder: Array[String] = controller.ladder()
	for round_index: int in ladder.size():
		steps.append(_step(controller, round_index, ladder[round_index]))
	var row: HBoxContainer = ScreenKit.row(steps, 20)
	column.add_child(row)
	var begin: Button = ScreenKit.button(tr("intro.begin"), CommonsTheme.PRIMARY)
	begin.pressed.connect(func() -> void: app.show_screen(app.table_id(), true))
	column.add_child(begin)
	ScreenKit.reveal(column)
	UiMotion.enter(steps)
	begin.grab_focus()


## The boss's name and rule, so the twist is never hidden (P4.7).
func _boss_line(controller: RunController) -> Label:
	var name_text: String = tr("modifier.%s.name" % controller.boss())
	var line: Label = ScreenKit.label(
		tr("intro.boss").format(
			{"name": name_text, "rule": controller.modifier_text(controller.boss())}
		),
		24
	)
	line.add_theme_color_override("font_color", ScreenKit.RED)
	return line


func _step(controller: RunController, round_index: int, debuff_id: String) -> Control:
	var card: VBoxContainer = ScreenKit.card(Vector2(330, 250))
	card.add_child(ScreenKit.eyebrow(tr("intro.round").format({"round": round_index + 1})))
	if debuff_id.is_empty():
		# A later round with nothing left to draw still carries the earlier debuffs.
		var held: bool = round_index > 0
		var title_key: String = "intro.none_new" if held else "intro.clean"
		var text_key: String = "intro.none_new_text" if held else "intro.clean_text"
		card.add_child(ScreenKit.styled(tr(title_key), CommonsTheme.TITLE))
		card.add_child(ScreenKit.styled(tr(text_key), CommonsTheme.CAPTION))
	else:
		var name: Label = ScreenKit.styled(tr("modifier.%s.name" % debuff_id), CommonsTheme.TITLE)
		name.add_theme_font_size_override("font_size", StoreScreen.NAME_SIZE)
		name.add_theme_color_override("font_color", ScreenKit.RED)
		card.add_child(name)
		card.add_child(ScreenKit.label(controller.modifier_text(debuff_id), 20))
	return ScreenKit.card_panel(card)
