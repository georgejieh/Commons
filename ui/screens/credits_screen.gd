class_name CreditsScreen
extends Control
## The credits, from the title: the game's own line and its licence as LICENSE says it,
## the pictures and sounds by their sources, the fonts with their licences, what else the
## build carries, and the engine's licence and notices. One sheet of paper that scrolls,
## by mouse, by up and down on keys or pad while it has focus, fading at its cut; Back
## and Escape go back to the title.
##
## Nothing here is typed twice. The records of the art, the sounds and the components are
## working files that never ship, so tools/write_credits.py carries what they say into
## data/credits/credits.json, and a test fails while that file is behind them. The engine
## reports its own licence and notices, so they are read from it as the screen opens, and
## the fonts' licences are read from art/fonts/, which every export carries for the OFL.

const CREDITS: JSON = preload("res://data/credits/credits.json")
const WIDTH: float = 1180.0
const HEADING_SIZE: int = 30
const BODY_SIZE: int = 24
## Licence texts keep their own line breaks, so they are set in the typewriter face.
const NOTICE_SIZE: int = 18

var _app: DemoApp = null
var _scroll: ProseScroll = null
var _back: Button = null
## True until the scroll has taken the focus it offers once it can scroll.
var _fresh: bool = true


func open(app: DemoApp) -> void:
	_app = app
	_fresh = true
	var column: VBoxContainer = ScreenKit.page(self)
	column.add_child(ScreenKit.header(tr("credits.eyebrow"), tr("credits.title")))
	var sheet: VBoxContainer = ScreenKit.card(Vector2(WIDTH, 0))
	var panel: Control = ScreenKit.card_panel(sheet)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll = ProseScroll.new(_text())
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ScrollFade.over(_scroll)
	_scroll.get_v_scroll_bar().changed.connect(_offer_focus)
	sheet.add_child(_scroll)
	column.add_child(panel)
	_back = ScreenKit.button(tr("settings.back"), CommonsTheme.PRIMARY)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_back.pressed.connect(func() -> void: _app.back())
	column.add_child(_back)
	ScreenKit.reveal(column)
	_back.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_app.back()


## The scroll and Back, for tests and the playtest.
func scroll() -> ProseScroll:
	return _scroll


func back_button() -> Button:
	return _back


## Once there is something to scroll, the scroll takes the focus from Back, so up and down
## read on at once; down past the end reaches Back.
func _offer_focus() -> void:
	if _fresh and _back != null and _scroll.can_scroll() and _back.has_focus():
		_fresh = false
		_scroll.grab_focus()


func _text() -> VBoxContainer:
	var data: Dictionary = CREDITS.data
	var text: VBoxContainer = VBoxContainer.new()
	text.add_theme_constant_override("separation", 14)
	text.add_child(_body(tr("credits.game")))
	_section(text, tr("credits.licence"))
	text.add_child(_notice(str(data["licence"])))
	_section(text, tr("credits.pictures"))
	for made: Dictionary in data["pictures"]:
		text.add_child(_body(tr("credits.pictures.line").format(made)))
	_section(text, tr("credits.sounds"))
	var sounds: Dictionary = data["sounds"]
	text.add_child(_body(tr("credits.sounds.made").format({"count": sounds["made"]})))
	for source: Dictionary in sounds["credited"]:
		var works: String = ", ".join(PackedStringArray(source["works"]))
		var shown: Dictionary = source.duplicate()
		shown["works"] = works
		text.add_child(_body(tr("credits.sounds.line").format(shown)))
	_section(text, tr("credits.type"))
	for font: Dictionary in data["fonts"]:
		text.add_child(_body(tr("credits.type.line").format(font)))
		var path: String = "res://" + str(font["file"])
		text.add_child(_notice(FileAccess.get_file_as_string(path).strip_edges()))
	_section(text, tr("credits.built"))
	for component: Dictionary in data["components"]:
		text.add_child(_body(tr("credits.built.line").format(component)))
	_engine(text)
	return text


## The engine's licence, each component inside it with its owners and licence, and the
## text of each licence they use, all as the engine reports them.
func _engine(text: VBoxContainer) -> void:
	_section(text, tr("credits.engine"))
	text.add_child(_body(tr("credits.engine.line")))
	text.add_child(_notice(Engine.get_license_text().strip_edges()))
	var licence_of: String = tr("credits.engine.licence_of")
	for component: Dictionary in Engine.get_copyright_info():
		var lines: PackedStringArray = [str(component["name"])]
		for part: Dictionary in component["parts"]:
			lines.append("\n".join(PackedStringArray(part["copyright"])))
			lines.append(licence_of.format({"licence": part["license"]}))
		text.add_child(_notice("\n".join(lines)))
	var licences: Dictionary = Engine.get_license_info()
	for licence: String in licences:
		text.add_child(_notice("%s\n\n%s" % [licence, str(licences[licence]).strip_edges()]))


func _section(text: VBoxContainer, heading: String) -> void:
	var label: Label = ScreenKit.label(heading, HEADING_SIZE, ScreenKit.INK)
	label.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
	text.add_child(label)


func _body(words: String) -> Label:
	var label: Label = ScreenKit.label(words, BODY_SIZE, ScreenKit.INK)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _notice(words: String) -> Label:
	var label: Label = ScreenKit.label(words, NOTICE_SIZE, ScreenKit.INK)
	label.add_theme_font_override("font", ScreenKit.TYPEWRITER)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label
