class_name TitleScreen
extends Control
## The title: start a new run through run setup, continue a saved one, or open the
## collection, village history or settings. While the family's file holds an entry, its
## stamp stands in the top right corner (ADR 0022).
## The page arrives in order and is whole in about a second and a half: the poster is
## laid down, the eyebrow fades in, the name is pressed letter by letter (TitleWord, the
## page's one moment), then the line under it, the buttons that start a run, and last
## the row of minor buttons, which only fades. Every button takes a press from the first
## frame.

var _stamp: FileStamp = null
var _word: TitleWord = null
## Seconds from opening until the last piece is in; 0 under reduced motion.
var _arrives_in: float = 0.0


func open(app: DemoApp) -> void:
	# The title reads the art's stage afresh, as a run's start does (ADR 0025).
	ArtStages.latch(Saves.profile_service())
	var column: VBoxContainer = ScreenKit.page(self, ScreenKit.ART.title_night)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var eyebrow: Label = ScreenKit.eyebrow(tr("title.eyebrow"))
	column.add_child(eyebrow)
	_word = TitleWord.new(tr("game.title"))
	column.add_child(_word)
	var subtitle: Label = ScreenKit.styled(tr("title.subtitle"), CommonsTheme.TITLE)
	subtitle.add_theme_font_size_override("font_size", TextSize.px(30))
	subtitle.add_theme_color_override("font_color", ScreenKit.STYLE.paper)
	subtitle.add_theme_color_override("font_outline_color", ScreenKit.INK)
	column.add_child(subtitle)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	column.add_child(spacer)
	var new_run: Button = ScreenKit.button(tr("title.new_run"), CommonsTheme.PRIMARY)
	new_run.pressed.connect(func() -> void: app.show_screen("run_setup"))
	column.add_child(new_run)
	if app.has_saved_run():
		var resume: Button = ScreenKit.button(tr("title.continue"))
		resume.pressed.connect(func() -> void: app.resume_to_screen())
		column.add_child(resume)
	var settings: Button = ScreenKit.button(tr("title.settings"), CommonsTheme.GHOST)
	settings.pressed.connect(func() -> void: app.show_screen("settings"))
	var quit: Button = ScreenKit.button(tr("title.quit"), CommonsTheme.GHOST)
	quit.pressed.connect(func() -> void: get_tree().quit())
	var collection: Button = ScreenKit.button(tr("title.collection"), CommonsTheme.GHOST)
	collection.pressed.connect(func() -> void: app.show_screen("collection"))
	var history: Button = ScreenKit.button(tr("title.history"), CommonsTheme.GHOST)
	history.pressed.connect(func() -> void: app.show_screen("village_history"))
	var minor: HBoxContainer = ScreenKit.row([collection, history, settings, quit])
	column.add_child(minor)
	_arrive(column, eyebrow, minor)
	new_run.grab_focus()
	var filed: int = ProfileFile.entries(Saves.profile_service()).size()
	if filed > 0:
		_stamp = FileStamp.new(filed)
		add_child(_stamp)


## The family's file's stamp, or null while the file is empty. For tests.
func stamp() -> FileStamp:
	return _stamp


## The game's name. For tests.
func word() -> TitleWord:
	return _word


## Seconds from opening until the whole page is in. For tests.
func arrives_in() -> float:
	return _arrives_in


## The poster under everything. For tests.
func poster() -> Control:
	return get_child(0) as Control


## Brings the page in, in order. The eyebrow and the minor row are small print and only
## fade; the spacer has nothing to show.
func _arrive(column: VBoxContainer, eyebrow: Control, minor: Control) -> void:
	if UiMotion.reduced():
		return
	var presets: MotionPresets = UiMotion.PRESETS
	UiMotion.settle(poster())
	var at: float = presets.title_start
	for child: Node in column.get_children():
		var piece: Control = child as Control
		if piece == _word:
			at += presets.title_stagger
			at += _word.press(at)
		elif piece is Label or piece is BaseButton or piece == minor:
			if piece != eyebrow:
				at += presets.title_stagger
			UiMotion.enter_at(piece, at, piece == eyebrow or piece == minor)
	_arrives_in = at + presets.enter_time
