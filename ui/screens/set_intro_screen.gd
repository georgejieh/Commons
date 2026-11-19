class_name SetIntroScreen
extends Control
## Before a Set: its type, its target and reward, how far the norm has raised it, who
## of the village sits at the table in a full run, and the debuff ladder drawn for it,
## one card per round, with round 1 always clean. Everything sits on one sheet at the
## left, the rounds two by two. Under a dark norm, or at the stage past the last, the
## target is "None reported" (ADR 0022).

const SHEET_WIDTH: float = 800.0
const STEP_SIZE: Vector2 = Vector2(370, 170)


func open(app: DemoApp) -> void:
	var controller: RunController = app.controller
	var state: RunState = controller.state_copy()
	var art: Texture2D = ScreenKit.ART.notice_wall
	var column: VBoxContainer = ScreenKit.side_sheet(self, art, SHEET_WIDTH)
	var where: String = tr("intro.where").format(
		{"year": state.year, "set": state.set_index + 1, "sets": app.sets_per_year()}
	)
	column.add_child(ScreenKit.header(where, tr("set.type.%d" % state.set_type)))
	var target: String = tr("intro.target").format(
		{"target": Strings.score(controller.target()), "rounds": app.max_rounds()}
	)
	# A dark norm hides the target, and with it how far the norm raised it (ADR 0022).
	var shown: bool = ShownFigures.shows_target(state)
	if not shown:
		target = tr("intro.target.unreported").format({"rounds": app.max_rounds()})
	column.add_child(ScreenKit.styled(target, CommonsTheme.TITLE))
	if controller.norm_percent() > 0 and shown:
		var norm: Label = ScreenKit.label(
			tr("intro.norm").format({"percent": controller.norm_percent()}), 24
		)
		norm.add_theme_color_override("font_color", ScreenKit.RED)
		column.add_child(norm)
	if controller.has_village():
		var names: String = ", ".join(
			[controller.seated_full_name(1), controller.seated_full_name(2)]
		)
		column.add_child(ScreenKit.label(tr("intro.seated").format({"names": names}), 24))
	if not controller.boss().is_empty():
		column.add_child(_boss_line(controller))
	var reforms: Label = reforms_line(controller)
	if reforms != null:
		column.add_child(reforms)
	column.add_child(ScreenKit.eyebrow(tr("intro.ladder")))
	var steps: Array[Control] = []
	var ladder: Array[String] = controller.ladder()
	for round_index: int in ladder.size():
		steps.append(_step(controller, round_index, ladder[round_index]))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	for step: Control in steps:
		grid.add_child(step)
	column.add_child(grid)
	var begin: Button = ScreenKit.button(tr("intro.begin"), CommonsTheme.PRIMARY)
	begin.pressed.connect(func() -> void: app.show_screen(app.table_id(), true))
	column.add_child(begin)
	ScreenKit.reveal(column)
	UiMotion.enter(steps)
	begin.grab_focus()
	# The first time a Quota lists a debuff, and the first time a family that remembers
	# the player sits down, a one-time tooltip says what that means (ADR 0026).
	var tips: Array[String] = []
	if ladder.any(func(debuff_id: String) -> bool: return not debuff_id.is_empty()):
		tips.append("tip.debuffs")
	if controller.remembers_seated():
		tips.append("tip.memory")
	TipSlip.offer(self, app, tips)


## The Reforms in force, named in one line, or null while none is (ADR 0021).
static func reforms_line(controller: RunController) -> Label:
	var names: PackedStringArray = []
	for reform_id: String in controller.held_reforms():
		names.append(controller.reform_name(reform_id))
	if names.is_empty():
		return null
	var text: String = TranslationServer.translate("reform.held_line")
	var line: Label = ScreenKit.label(text.format({"names": ", ".join(names)}), 24)
	return line


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
	var card: VBoxContainer = ScreenKit.card(STEP_SIZE)
	card.add_child(ScreenKit.eyebrow(tr("intro.round").format({"round": round_index + 1})))
	if debuff_id.is_empty():
		# A later round with nothing left to draw still carries the earlier debuffs.
		var held: bool = round_index > 0
		var title_key: String = "intro.none_new" if held else "intro.clean"
		var text_key: String = "intro.none_new_text" if held else "intro.clean_text"
		card.add_child(ScreenKit.styled(tr(title_key), CommonsTheme.TITLE))
		card.add_child(ScreenKit.styled(tr(text_key), CommonsTheme.CAPTION))
	else:
		var name: Label = ScreenKit.styled(controller.modifier_name(debuff_id), CommonsTheme.TITLE)
		name.add_theme_font_size_override("font_size", TextSize.px(StoreScreen.NAME_SIZE))
		name.add_theme_color_override("font_color", ScreenKit.RED)
		card.add_child(name)
		var rule: KeywordText = KeywordText.new()
		rule.add_theme_font_size_override("normal_font_size", TextSize.px(20))
		rule.add_theme_color_override("default_color", ScreenKit.INK)
		rule.set_rule(ScreenKit.rule_text(controller, debuff_id))
		card.add_child(rule)
	return ScreenKit.card_panel(card)
