class_name Keywords
extends RefCounted
## The game's scoring words, marked wherever rules text names them: each prints in its
## own ink and explains itself on hover. Plain labels get the same explanations as a
## tooltip. The words and their meanings come from the string table.

## Keyword IDs and their inks: Grain in wheat ochre, Zeal in stamp vermilion, the
## Commons in ration green.
const INKS: Dictionary[String, String] = {
	"grain": "8a5a12",
	"zeal": "b02a17",
	"commons": "3f6338",
}


## text as BBCode with every keyword colored and explained on hover.
static func mark(text: String) -> String:
	var marked: String = text.replace("[", "[lb]")
	# Two passes, so a word inside another keyword's explanation is never marked.
	for id: String in INKS:
		var word: String = TranslationServer.translate("keyword.%s.name" % id)
		marked = marked.replace(word, "<<%s>>" % id)
	for id: String in INKS:
		var word: String = TranslationServer.translate("keyword.%s.name" % id)
		var tip: String = TranslationServer.translate("keyword.%s.text" % id)
		var styled: String = "[hint=%s][color=#%s]%s[/color][/hint]" % [tip, INKS[id], word]
		marked = marked.replace("<<%s>>" % id, styled)
	return marked


## The meaning of every keyword text names, one per line, for a plain label's tooltip.
static func tip(text: String) -> String:
	var lines: PackedStringArray = []
	for id: String in INKS:
		if text.contains(TranslationServer.translate("keyword.%s.name" % id)):
			lines.append(TranslationServer.translate("keyword.%s.text" % id))
	return "\n".join(lines)


## Every keyword's meaning, for the rules sheet.
static func glossary() -> String:
	var lines: PackedStringArray = []
	for id: String in INKS:
		lines.append(TranslationServer.translate("keyword.%s.text" % id))
	return "\n".join(lines)
