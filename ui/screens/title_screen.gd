class_name TitleScreen
extends Control
## The title: start a new run through run setup, continue a saved one, or open the
## collection, village history, settings or credits, or, once the profile has finished or
## skipped the arrival, play it again (ADR 0026). While the family's file holds an entry,
## its stamp stands in the top right corner (ADR 0022). After a session that did not close,
## a notice over the page says where its files were copied (ADR 0037).
## The page arrives in order and is whole in about a second and a half: the poster is
## laid down, the eyebrow fades in, the name is pressed letter by letter (TitleWord, the
## page's one moment), then the line under it, the buttons that start a run, and last
## the row of minor buttons, which only fades. Every button takes a press from the first
## frame.
## The column stands at the top of the page, in the poster's sky: its foot is above SKY
## of the page's height, where the crowd's faces begin, so no button lies on a face.
## Continue stands beside New Run, so a saved run adds no row to the column.

## The share of the page's height the poster's sky takes, down to the crowd.
const SKY: float = 0.6
## The faces nearest the buttons in the poster, as shares of the picture: the young man's
## head at the left, the woman beside him, and the man at the left edge. For tests.
const FACES: Array[Rect2] = [
	Rect2(0.02, 0.62, 0.16, 0.21),
	Rect2(0.21, 0.71, 0.14, 0.22),
	Rect2(0.0, 0.77, 0.07, 0.16),
]

## The name of the Replay the arrival button, for tests.
const REPLAY: String = "ReplayArrival"
## The line under the name, at Standard.
const SUBTITLE_SIZE: int = 30

var _stamp: FileStamp = null
var _word: TitleWord = null
## Seconds from opening until the last piece is in; 0 under reduced motion.
var _arrives_in: float = 0.0


func open(app: App) -> void:
	# The title reads the art's stage afresh, as a run's start does (ADR 0025).
	ArtStages.latch(Saves.profile_service())
	var column: VBoxContainer = ScreenKit.page(self, ScreenKit.ART.title_night)
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	# Paper letters edged in ink, as the line under the name is: crisp on the poster.
	var eyebrow: Label = ScreenKit.eyebrow(tr("title.eyebrow"))
	eyebrow.add_theme_color_override("font_color", ScreenKit.PAPER)
	eyebrow.add_theme_color_override("font_outline_color", ScreenKit.INK)
	eyebrow.add_theme_constant_override("outline_size", 6)
	column.add_child(eyebrow)
	_word = TitleWord.new(tr("game.title"))
	column.add_child(_word)
	var subtitle: Label = ScreenKit.styled(tr("title.subtitle"), CommonsTheme.TITLE)
	subtitle.add_theme_font_size_override("font_size", TextSize.px(SUBTITLE_SIZE))
	subtitle.add_theme_color_override("font_color", ScreenKit.PAPER)
	subtitle.add_theme_color_override("font_outline_color", ScreenKit.INK)
	column.add_child(subtitle)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	column.add_child(spacer)
	var new_run: Button = ScreenKit.button(tr("title.new_run"), CommonsTheme.PRIMARY)
	new_run.pressed.connect(func() -> void: app.show_screen(App.RUN_SETUP))
	var starts: HBoxContainer = ScreenKit.row([new_run])
	if app.has_saved_run():
		var resume: Button = ScreenKit.button(tr("title.continue"))
		resume.pressed.connect(func() -> void: app.resume_to_screen())
		starts.add_child(resume)
	column.add_child(starts)
	var minor: HBoxContainer = _minors(app)
	column.add_child(minor)
	_arrive(column, eyebrow, starts, minor)
	new_run.grab_focus()
	_notices(app, new_run)


## The row of minor buttons: the collection, the history, the arrival again once it has
## been played, the settings, the credits and Quit.
func _minors(app: App) -> HBoxContainer:
	var settings: Button = ScreenKit.button(tr("title.settings"), CommonsTheme.GHOST)
	settings.pressed.connect(func() -> void: app.show_screen(App.SETTINGS))
	var credits: Button = ScreenKit.button(tr("title.credits"), CommonsTheme.GHOST)
	credits.pressed.connect(func() -> void: app.show_screen(App.CREDITS))
	var quit: Button = ScreenKit.button(tr("title.quit"), CommonsTheme.GHOST)
	quit.pressed.connect(func() -> void: get_tree().quit())
	var collection: Button = ScreenKit.button(tr("title.collection"), CommonsTheme.GHOST)
	collection.pressed.connect(func() -> void: app.show_screen(App.COLLECTION))
	var history: Button = ScreenKit.button(tr("title.history"), CommonsTheme.GHOST)
	history.pressed.connect(func() -> void: app.show_screen(App.VILLAGE_HISTORY))
	var minors: Array[Control] = [collection, history]
	if ProfileSeen.has(Saves.profile_service(), ProfileSeen.TUTORIAL):
		minors.append(_replay_button(app))
	minors.append_array([settings, credits, quit])
	return ScreenKit.row(minors)


## The family's file's stamp while it holds an entry, and the notice of a session that did
## not close, after which New Run takes the focus back.
func _notices(app: App, new_run: Button) -> void:
	var filed: int = ProfileFile.entries(Saves.profile_service()).size()
	if filed > 0:
		_stamp = FileStamp.new(filed)
		add_child(_stamp)
	# The last session did not close (ADR 0037): said once, over the page.
	if not app.kept_crash.is_empty():
		var kept: SessionNotice = SessionNotice.kept(app.kept_crash)
		add_child(kept)
		kept.buttons()[0].pressed.connect(new_run.grab_focus)
		app.kept_crash = ""


## The arrival again (ADR 0026). It is never saved and ends at the title, so a saved run
## and the profile are left as they were.
func _replay_button(app: App) -> Button:
	var replay: Button = ScreenKit.button(tr("title.replay_arrival"), CommonsTheme.GHOST)
	replay.name = REPLAY
	replay.pressed.connect(func() -> void: app.arrival.start(true))
	return replay


## The Replay the arrival button, or null when there is no arrival to replay. For tests.
func replay_button() -> Button:
	return find_child(REPLAY, true, false) as Button


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
func _arrive(column: VBoxContainer, eyebrow: Control, starts: Control, minor: Control) -> void:
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
		elif piece is Label or piece == starts or piece == minor:
			if piece != eyebrow:
				at += presets.title_stagger
			UiMotion.enter_at(piece, at, piece == eyebrow or piece == minor)
	_arrives_in = at + presets.enter_time
