class_name SizeScan
extends RefCounted
## The font size scan of ADR 0034. In ui/, every size handed to
## add_theme_font_size_override, draw_string, draw_multiline_string, a theme's
## set_font_size or default_font_size, NameFit and BBCode's font_size tag comes from
## TextSize. A size passes when its call holds TextSize itself, or names a value the same
## script took from TextSize, or calls a function of the same script that asks TextSize.
## A name is matched by its spelling within the script, so a value of the same name set
## another way elsewhere in it would pass too. Scenes and resources under ui/ set no font
## size at all.

const SIZE_CALLS: String = (
	r"(?<!\w)(?:add_theme_font_size_override|draw_string|draw_multiline_string"
	+ r"|set_font_size|NameFit\.(?:apply|size_for))\s*\("
)
const SIZE_LINES: String = r"default_font_size\s*=|\[font_size="
const FUNC: String = r"(?m)^(?:static\s+)?func\s+([A-Za-z_]\w*)"
const ASSIGNED: String = r"(?m)^\s*(?:var\s+)?([A-Za-z_]\w*)\s*(?::[^=\n]*)?=(?!=)([^\n]*)$"
const WORD: String = r"[A-Za-z_]\w*"
const ASKS: String = "TextSize."


## The font sizes in one file that do not come from TextSize.
static func offences(path: String, text: String) -> PackedStringArray:
	var found: PackedStringArray = []
	if path.get_extension() != "gd":
		var lines: PackedStringArray = text.split("\n")
		for index: int in lines.size():
			if lines[index].contains("font_size"):
				found.append("%s:%d: %s" % [path, index + 1, lines[index].strip_edges()])
		return found
	var code: String = SourceScan.code_of(text)
	var sized: Dictionary[String, bool] = sized_names(code)
	for span: Vector3i in SourceScan.calls(code, SIZE_CALLS):
		if not _asks(code.substr(span.y, span.z - span.y), sized):
			var head: String = code.substr(span.x, span.y - span.x)
			found.append("%s:%d: %s" % [path, SourceScan.line_of(code, span.x), head])
	var code_lines: PackedStringArray = code.split("\n")
	for index: int in code_lines.size():
		var line: String = code_lines[index]
		if SourceScan.pattern(SIZE_LINES).search(line) != null and not _asks(line, sized):
			found.append("%s:%d: %s" % [path, index + 1, line.strip_edges()])
	return found


## The functions of the script that ask TextSize, and the values it takes from TextSize
## or from those functions.
static func sized_names(code: String) -> Dictionary[String, bool]:
	var sized: Dictionary[String, bool] = {}
	var heads: Array[RegExMatch] = SourceScan.pattern(FUNC).search_all(code)
	for index: int in heads.size():
		var end: int = heads[index + 1].get_start() if index + 1 < heads.size() else code.length()
		var body: String = code.substr(heads[index].get_end(), end - heads[index].get_end())
		if body.contains(ASKS):
			sized[heads[index].get_string(1)] = true
	for hit: RegExMatch in SourceScan.pattern(ASSIGNED).search_all(code):
		if _asks(hit.get_string(2), sized):
			sized[hit.get_string(1)] = true
	return sized


static func _asks(text: String, sized: Dictionary[String, bool]) -> bool:
	if text.contains(ASKS):
		return true
	# A name inside a string, such as "font_size", is not a value.
	var bare: String = SourceScan.pattern(SourceScan.LITERAL).sub(text, '""', true)
	for word: RegExMatch in SourceScan.pattern(WORD).search_all(bare):
		if sized.has(word.get_string()):
			return true
	return false
