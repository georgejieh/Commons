class_name ContentNoteScreen
extends Control
## The content note shown once, before the title, on first launch: the themes
## the game shows and how to turn the horror down. Continue records that it was seen,
## then leads to the Arrival page on a first launch, or the title (ADR 0026).

## The note's lines, at Standard.
const LINE_SIZE: int = 26


func open(app: DemoApp) -> void:
	var sheet: VBoxContainer = ScreenKit.centered_sheet(self, ScreenKit.ART.title_night)
	sheet.add_child(ScreenKit.header(tr("note.eyebrow"), tr("note.title")))
	for key: String in ["note.themes", "note.board", "note.settings"]:
		var line: Label = ScreenKit.label(tr(key), LINE_SIZE)
		line.custom_minimum_size = Vector2(900, 0)
		sheet.add_child(line)
	var next: Button = ScreenKit.button(tr("note.continue"), CommonsTheme.PRIMARY)
	next.pressed.connect(
		func() -> void:
			Settings.set_value(DemoApp.CONTENT_NOTE_SEEN, true)
			Settings.save()
			app.show_screen(app.arrival.next_screen(), true)
	)
	sheet.add_child(next)
	ScreenKit.reveal(sheet)
	next.grab_focus()


## The note's whole text, for tests.
func text() -> String:
	return "\n".join([tr("note.themes"), tr("note.board"), tr("note.settings")])
