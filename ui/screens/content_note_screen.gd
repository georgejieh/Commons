class_name ContentNoteScreen
extends Control
## The content note shown once, before the title, on first launch (P3B.12): the themes
## the game shows and how to turn the horror down. Continue records that it was seen.


func open(app: DemoApp) -> void:
	var sheet: VBoxContainer = ScreenKit.centered_sheet(self, ScreenKit.ART.title_night)
	sheet.add_child(ScreenKit.header(tr("note.eyebrow"), tr("note.title")))
	for key: String in ["note.themes", "note.board", "note.settings"]:
		var line: Label = ScreenKit.label(tr(key), 26)
		line.custom_minimum_size = Vector2(900, 0)
		sheet.add_child(line)
	var next: Button = ScreenKit.button(tr("note.continue"), CommonsTheme.PRIMARY)
	next.pressed.connect(
		func() -> void:
			Settings.set_value("content_note_seen", true)
			Settings.save()
			app.show_screen("title", true)
	)
	sheet.add_child(next)
	ScreenKit.reveal(sheet)
	next.grab_focus()


## The note's whole text, for tests.
func text() -> String:
	return "\n".join([tr("note.themes"), tr("note.board"), tr("note.settings")])
