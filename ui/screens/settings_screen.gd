class_name SettingsScreen
extends Control
## Volumes, motion and the print pass on one sheet, and beside it the card back designs
## (ADR 0025). Changes apply at once and save on the way back.

var _card_backs: CardBackRow


func open(app: DemoApp) -> void:
	var column: VBoxContainer = ScreenKit.page(self)
	column.add_child(ScreenKit.header(tr("settings.eyebrow"), tr("settings.title")))
	var backs: VBoxContainer = ScreenKit.card(Vector2(0, 0))
	_card_backs = CardBackRow.new(CardBacks.profile_runs())
	backs.add_child(_card_backs)
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
	column.add_child(back)
	ScreenKit.reveal(column)
	back.grab_focus()


## The card back row, for tests.
func card_backs() -> CardBackRow:
	return _card_backs
