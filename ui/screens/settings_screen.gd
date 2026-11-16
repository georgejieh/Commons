class_name SettingsScreen
extends Control
## Volumes, motion and the print pass on one sheet, and beside it the card back designs
## (ADR 0025), and under them the family's name with a way to change it between runs
## (ADR 0028). Changes apply at once and save on the way back. Replay the arrival plays
## the first evening again (ADR 0026).

var _card_backs: CardBackRow
var _change: Button = null
var _name_line: Label


func open(app: DemoApp) -> void:
	var column: VBoxContainer = ScreenKit.page(self)
	column.add_child(ScreenKit.header(tr("settings.eyebrow"), tr("settings.title")))
	var backs: VBoxContainer = ScreenKit.card(Vector2(0, 0))
	_card_backs = CardBackRow.new(CardBacks.profile_runs())
	backs.add_child(_card_backs)
	backs.add_child(_family_name(app))
	var sheets: HBoxContainer = ScreenKit.row([SettingsPanel.build(), ScreenKit.card_panel(backs)])
	sheets.alignment = BoxContainer.ALIGNMENT_BEGIN
	for sheet: Node in sheets.get_children():
		(sheet as Control).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	column.add_child(sheets)
	var back: Button = ScreenKit.button(tr("settings.back"), CommonsTheme.PRIMARY)
	back.pressed.connect(
		func() -> void:
			Settings.save()
			app.back()
	)
	# The arrival again (ADR 0026): it ends at the title and changes nothing saved.
	var replay: Button = ScreenKit.button(tr("settings.replay_arrival"), CommonsTheme.GHOST)
	replay.pressed.connect(
		func() -> void:
			Settings.save()
			app.arrival.start(true)
	)
	column.add_child(ScreenKit.row([back, replay]))
	ScreenKit.reveal(column)
	back.grab_focus()


## The card back row, for tests.
func card_backs() -> CardBackRow:
	return _card_backs


## The family name's Change button, or null while a run stops it, and the line shown.
func change_button() -> Button:
	return _change


func name_line() -> String:
	return _name_line.text


## The surname, then Change, or while a run is saved or the arrival plays, why not.
func _family_name(app: DemoApp) -> VBoxContainer:
	var block: VBoxContainer = VBoxContainer.new()
	block.add_child(ScreenKit.eyebrow(tr("settings.family_name")))
	_name_line = ScreenKit.label(Surnames.of_profile(Saves.profile_service()), 30)
	var running: bool = app.has_saved_run() or app.arrival.is_running()
	if running:
		block.add_child(_name_line)
		block.add_child(ScreenKit.label(tr("settings.name_locked"), 20))
		return block
	_change = ScreenKit.button(tr("settings.change_name"), CommonsTheme.SECONDARY)
	_change.pressed.connect(
		func() -> void:
			Settings.save()
			app.show_screen("surname")
	)
	block.add_child(ScreenKit.row([_name_line, _change]))
	return block
