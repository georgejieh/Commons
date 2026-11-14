class_name Keywords
extends RefCounted
## The game's own words, marked wherever rules text names them. Each prints underlined
## in ink, like a link, and explains itself on hover, so rules text stays short. The
## scoring words keep their own inks. Words and meanings come from the string table.

## Every keyword ID, in glossary order.
const TERMS: PackedStringArray = [
	"grain",
	"rate",
	"zeal",
	"commons",
	"landlord",
	"peasant",
	"kitty",
	"kicker",
	"bomb",
	"rocket",
	"quota",
	"audit",
	"resentment",
	"denunciation",
	"famine",
]
## Scoring words print in their own inks: Grain in wheat ochre, Rate in indigo, Zeal
## in stamp vermilion, the Commons in ration green. Every other keyword uses LINK.
const INKS: Dictionary[String, String] = {
	"grain": "8a5a12",
	"rate": "5b3f8a",
	"zeal": "b02a17",
	"commons": "3f6338",
}
const LINK: String = "2b4a6b"
## The width a tooltip wraps to, and its type size.
const SLIP_WIDTH: float = 400.0
const SLIP_SIZE: int = 20
const WRAP_COLUMNS: int = 52
const SOFT: Color = Color("5a4a36")

static var _patterns: Dictionary[String, RegEx] = {}


## text as BBCode with every keyword underlined, colored and explained on hover. A
## keyword matches in any case and in the plural, and prints as it was written.
static func mark(text: String) -> String:
	var marked: String = text.replace("[", "[lb]")
	# Two passes, so a word inside another keyword's explanation is never marked.
	for index: int in TERMS.size():
		marked = _pattern(TERMS[index]).sub(marked, "\u0001%d\u0002$0\u0003" % index, true)
	for index: int in TERMS.size():
		var id: String = TERMS[index]
		# The hint is quoted, so only a quote or a bracket could end it early.
		var tip: String = meaning(id).replace('"', "'").replace("[", "(").replace("]", ")")
		var open: String = '[hint="%s"][color=#%s][u]' % [tip, INKS.get(id, LINK)]
		marked = marked.replace("\u0001%d\u0002" % index, open)
	return marked.replace("\u0003", "[/u][/color][/hint]")


## The keywords text names, in glossary order.
static func found(text: String) -> PackedStringArray:
	var ids: PackedStringArray = []
	for id: String in TERMS:
		if _pattern(id).search(text) != null:
			ids.append(id)
	return ids


static func meaning(id: String) -> String:
	return TranslationServer.translate("keyword.%s.text" % id)


## The meaning of every keyword text names, one per line, for a plain tooltip.
static func tip(text: String) -> String:
	return glossary(found(text))


## The meanings of these keywords, one per line, wrapped for a plain tooltip unless
## the label showing them wraps by itself.
static func glossary(ids: PackedStringArray, wrap_lines: bool = true) -> String:
	var lines: PackedStringArray = []
	for id: String in ids:
		lines.append(wrapped(meaning(id)) if wrap_lines else meaning(id))
	return "\n".join(lines)


## text broken into lines of at most columns characters, for the engine's own
## tooltips, which never wrap.
static func wrapped(text: String, columns: int = WRAP_COLUMNS) -> String:
	var lines: PackedStringArray = []
	for paragraph: String in text.split("\n"):
		var line: String = ""
		for word: String in paragraph.split(" "):
			if not line.is_empty() and line.length() + word.length() + 1 > columns:
				lines.append(line)
				line = word
			else:
				line = word if line.is_empty() else line + " " + word
		lines.append(line)
	return "\n".join(lines)


## A tooltip's contents: an optional title, the text with its keywords marked, then
## what each keyword means in smaller type. It wraps, so a long rule never runs off
## the screen.
static func slip(text: String, title: String = "") -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(SLIP_WIDTH, 0)
	box.add_theme_constant_override("separation", 6)
	if not title.is_empty():
		var head: Label = Label.new()
		head.text = title
		head.add_theme_font_size_override("font_size", SLIP_SIZE + 4)
		head.add_theme_color_override("font_color", ScreenKit.INK)
		box.add_child(head)
	box.add_child(_slip_text(mark(text), SLIP_SIZE, ScreenKit.INK))
	var words: PackedStringArray = found(text)
	if not words.is_empty():
		box.add_child(HSeparator.new())
	for id: String in words:
		box.add_child(_slip_text(meaning(id).replace("[", "[lb]"), SLIP_SIZE - 4, SOFT))
	return box


static func _slip_text(bbcode: String, font_size: int, color: Color) -> RichTextLabel:
	var made: RichTextLabel = RichTextLabel.new()
	made.bbcode_enabled = true
	made.fit_content = true
	made.scroll_active = false
	made.custom_minimum_size = Vector2(SLIP_WIDTH, 0)
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	made.add_theme_font_size_override("normal_font_size", font_size)
	made.add_theme_color_override("default_color", color)
	made.text = bbcode
	return made


## Matches the keyword's name as a whole word, in any case, with a plural ending.
static func _pattern(id: String) -> RegEx:
	if not _patterns.has(id):
		var word: String = TranslationServer.translate("keyword.%s.name" % id)
		_patterns[id] = RegEx.create_from_string("(?i)\\b%s(?:s|es)?\\b" % word)
	return _patterns[id]
