class_name SetIntroScreen
extends Control
## Before a Set: its type, its target and reward, how far the norm has raised it, who
## of the village sits at the table in a full run, and the debuff ladder drawn for it,
## one card per round, with round 1 always clean. Everything sits on one sheet at the
## left, the rounds two by two. Under a dark norm, or at the stage past the last, the
## target is "None reported" (ADR 0022).

const SHEET_WIDTH: float = 830.0
const STEP_SIZE: Vector2 = Vector2(370, 170)
## The lines under the target, and a debuff's rules, at Standard.
const LINE_SIZE: int = 24
const RULE_SIZE: int = 20


func open(app: DemoApp) -> void:
	var controller: RunController = app.controller
	var state: RunView = controller.run
	var art: Texture2D = ScreenKit.ART.notice_wall
	var column: VBoxContainer = SheetPad.column(ScreenKit.side_sheet(self, art, SHEET_WIDTH))
	var where: String = tr("intro.where").format(
		{"year": state.year(), "set": state.set_index() + 1, "sets": app.sets_per_year()}
	)
	column.add_child(ScreenKit.header(where, tr("set.type.%d" % state.set_type())))
	var target: String = tr("intro.target").format(
		{"target": Strings.score(controller.figures.target()), "rounds": app.max_rounds()}
	)
	# A dark norm hides the target, and with it how far the norm raised it (ADR 0022).
	var shown: bool = ShownFigures.shows_target(state)
	if not shown:
		target = tr("intro.target.unreported").format({"rounds": app.max_rounds()})
	column.add_child(ScreenKit.styled(target, CommonsTheme.TITLE))
	_add_notes(column, controller, shown)
	# The ladder's caption wraps, so at a larger text size it keeps inside the sheet.
	var caption: Label = ScreenKit.eyebrow(tr("intro.ladder"))
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(caption)
	var steps: Array[Control] = _ladder(column, controller)
	var begin: Button = ScreenKit.button(tr("intro.begin"), CommonsTheme.PRIMARY)
	begin.pressed.connect(func() -> void: app.show_screen(app.table_id(), true))
	column.add_child(begin)
	ScreenKit.reveal(column)
	UiMotion.enter(steps)
	begin.grab_focus()
	_offer_tips(app)


## The lines under the target: how far the norm raised it while it shows, who sits at
## the table, the boss and the Reforms in force.
func _add_notes(column: VBoxContainer, controller: RunController, shown: bool) -> void:
	if controller.figures.norm_percent() > 0 and shown:
		var norm: Label = ScreenKit.label(
			tr("intro.norm").format(
				{
					"percent": controller.figures.norm_percent(),
					"step": controller.figures.norm_step_percent()
				}
			),
			LINE_SIZE
		)
		norm.add_theme_color_override("font_color", ScreenKit.RED)
		norm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(norm)
	if controller.seats.has_village():
		var names: String = ", ".join(
			[controller.seats.seated_full_name(1), controller.seats.seated_full_name(2)]
		)
		column.add_child(ScreenKit.label(tr("intro.seated").format({"names": names}), LINE_SIZE))
	if not controller.items.boss().is_empty():
		column.add_child(_boss_line(controller))
	var reforms: Label = _reforms_line(controller)
	if reforms != null:
		column.add_child(reforms)


## The debuff ladder, one card a round, two by two; returns the cards.
func _ladder(column: VBoxContainer, controller: RunController) -> Array[Control]:
	var steps: Array[Control] = []
	var ladder: Array[String] = controller.items.ladder()
	for round_index: int in ladder.size():
		steps.append(_step(controller, round_index, ladder[round_index]))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	for step: Control in steps:
		grid.add_child(step)
	column.add_child(grid)
	return steps


func _offer_tips(app: DemoApp) -> void:
	var controller: RunController = app.controller
	var ladder: Array[String] = controller.items.ladder()
	# The first time a Quota lists a debuff, and the first time a family that remembers
	# the player sits down, a one-time tooltip says what that means (ADR 0026).
	var tips: Array[String] = []
	if ladder.any(func(debuff_id: String) -> bool: return not debuff_id.is_empty()):
		tips.append("tip.debuffs")
	if controller.seats.remembers_seated():
		tips.append("tip.memory")
	# Beside the sheet, never over it.
	TipSlip.offer(self, app, tips, true)


## The Reforms in force, named in one line, or null while none is (ADR 0021).
static func _reforms_line(controller: RunController) -> Label:
	var names: PackedStringArray = []
	for reform_id: String in controller.items.held_reforms():
		names.append(controller.texts.reform_name(reform_id))
	if names.is_empty():
		return null
	var text: String = TranslationServer.translate("reform.held_line")
	var line: Label = ScreenKit.label(text.format({"names": ", ".join(names)}), LINE_SIZE)
	return line


## The boss's name and rule, so the twist is never hidden.
func _boss_line(controller: RunController) -> Label:
	var name_text: String = tr("modifier.%s.name" % controller.items.boss())
	var line: Label = ScreenKit.label(
		tr("intro.boss").format(
			{"name": name_text, "rule": controller.texts.modifier_text(controller.items.boss())}
		),
		LINE_SIZE
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
		var title: Label = ScreenKit.styled(
			controller.texts.modifier_name(debuff_id), CommonsTheme.TITLE
		)
		title.add_theme_font_size_override("font_size", TextSize.px(StoreScreen.NAME_SIZE))
		title.add_theme_color_override("font_color", ScreenKit.RED)
		card.add_child(title)
		var rule: KeywordText = KeywordText.new()
		rule.add_theme_font_size_override("normal_font_size", TextSize.px(RULE_SIZE))
		rule.add_theme_color_override("default_color", ScreenKit.INK)
		rule.set_rule(ScreenKit.rule_text(controller, debuff_id))
		card.add_child(rule)
	return ScreenKit.card_panel(card)
