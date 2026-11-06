class_name RunSetupScreen
extends Control
## Run setup (P3B.9): choose a stake, then start. Only the base stake exists until
## stakes unlock with meta-progression (P4.14).


func open(app: DemoApp) -> void:
	var sheet: VBoxContainer = ScreenKit.centered_sheet(self, ScreenKit.ART.title_night)
	sheet.add_child(ScreenKit.header(tr("setup.eyebrow"), tr("setup.title")))
	var stake: Button = ScreenKit.button(tr("setup.stake_base"), CommonsTheme.SECONDARY)
	stake.toggle_mode = true
	stake.button_pressed = true
	sheet.add_child(stake)
	sheet.add_child(ScreenKit.label(tr("setup.stake_base_text"), 22))
	sheet.add_child(ScreenKit.styled(tr("setup.locked"), CommonsTheme.CAPTION))
	var start: Button = ScreenKit.button(tr("setup.start"), CommonsTheme.PRIMARY)
	start.pressed.connect(
		func() -> void:
			app.new_run(int(Time.get_unix_time_from_system()))
			app.show_screen("set_intro", true)
	)
	var back: Button = ScreenKit.button(tr("setup.back"), CommonsTheme.GHOST)
	back.pressed.connect(app.back)
	sheet.add_child(ScreenKit.row([start, back]))
	ScreenKit.reveal(sheet)
	start.grab_focus()
