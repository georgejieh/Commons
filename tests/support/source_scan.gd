class_name SourceScan
extends RefCounted
## Reads the project's own scripts, scenes and resources for the text scans of P5.1.
## Each check takes one file's path and text, so a test can feed it a made-up line, and
## returns its offences as "path:line: what". Comments are blanked before a script is
## read, so offsets and line numbers stay as they were.
##
## A literal reaches the player when it is assigned to text, tooltip_text,
## placeholder_text or title; when it is an argument of draw_string,
## draw_multiline_string, append_text, add_text or ScreenKit's label, button, header,
## styled or eyebrow; when a scene or resource sets text, tooltip_text, placeholder_text
## or title to it; and wherever it reads as prose, two words or more. Such a literal must
## be a key of the table, or a key with %s or %d in it, or carry no words at all once
## its BBCode tags and placeholders are taken out. Developer text is never read: the
## arguments of assert, push_error, push_warning, the print family, Color, load, preload,
## RegEx and the export annotations, a dictionary's keys, the names format() fills, and
## the keys handed to tr, TranslationServer.translate and Strings, which key_offences
## checks instead.

const ROOTS: Array[String] = ["res://core", "res://game", "res://ui", "res://data"]
const TABLE_PATH: String = "res://data/strings/strings.csv"
const DEVELOPER_CALLS: String = (
	r"(?<![\w.])(?:assert|push_error|push_warning|print|printerr|prints|print_rich"
	+ r"|print_debug|Color|load|preload|RegEx\.create_from_string|@export_group"
	+ r"|@export_subgroup|@export_category|@export_enum)\s*\("
)
const KEY_CALLS: String = r"(?<![\w.])(?:tr|_tr|TranslationServer\.translate|Strings\.count)\s*\("
const FORMAT_CALLS: String = r"\.format\s*\("
const TEXT_CALLS: String = (
	r"(?<!\w)(?:draw_string|draw_multiline_string|append_text|add_text"
	+ r"|ScreenKit\.(?:label|button|header|styled|eyebrow))\s*\("
)
const TEXT_ASSIGNED: String = (
	r"(?m)\b(?:text|tooltip_text|placeholder_text|title)" + r"\s*\+?=(?!=)([^\n]*)"
)
const TEXT_PROPERTY: String = r'^(?:text|tooltip_text|placeholder_text|title) = "(.*)"$'
const LITERAL: String = "\"((?:[^\"\\\\\\n]|\\\\.)*)\"|'((?:[^'\\\\\\n]|\\\\.)*)'"
## A key, or a key with placeholders: lowercase words joined by dots.
const KEY_SHAPE: String = r"^[a-z0-9_]+(?:\.[a-z0-9_%]+)+\.?$"
## What does not count as words: BBCode tags, placeholders and escapes.
const NOT_WORDS: String = r"\[[^\]]*\]|%[-+0-9.]*[sdfxXc%]|\{[a-z_0-9]*\}|\\."
const PROSE: String = r"[A-Za-z]+[,.;:!?]?\s+[A-Za-z]+"
const CJK: String = (
	"[\\x{2E80}-\\x{2FDF}\\x{3000}-\\x{30FF}\\x{3400}-\\x{4DBF}\\x{4E00}-\\x{9FFF}"
	+ "\\x{AC00}-\\x{D7AF}\\x{F900}-\\x{FAFF}\\x{FF00}-\\x{FFEF}\\x{20000}-\\x{2FA1F}]"
)

static var _patterns: Dictionary[String, RegEx] = {}


## Every file under roots with one of the extensions, depth first.
static func files(roots: Array[String], extensions: Array[String]) -> PackedStringArray:
	var found: PackedStringArray = []
	for root: String in roots:
		for name: String in DirAccess.get_files_at(root):
			if extensions.has(name.get_extension()):
				found.append(root.path_join(name))
		for folder: String in DirAccess.get_directories_at(root):
			found.append_array(files([root.path_join(folder)], extensions))
	return found


static func read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


## The table's rows, its header first.
static func table_rows() -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var file: FileAccess = FileAccess.open(TABLE_PATH, FileAccess.READ)
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() > 1 or (row.size() == 1 and not row[0].is_empty()):
			rows.append(row)
	return rows


static func table_keys() -> Dictionary[String, bool]:
	var keys: Dictionary[String, bool] = {}
	for row: PackedStringArray in table_rows().slice(1):
		keys[row[0]] = true
	return keys


static func pattern(source: String) -> RegEx:
	if not _patterns.has(source):
		_patterns[source] = RegEx.create_from_string(source)
	return _patterns[source]


## A script's text with every comment blanked, so offsets and lines stay as they were.
static func code_of(text: String) -> String:
	var lines: PackedStringArray = text.split("\n")
	for index: int in lines.size():
		var line: String = lines[index]
		if line.contains("#"):
			lines[index] = _without_comment(line)
	return "\n".join(lines)


static func _without_comment(line: String) -> String:
	var quote: String = ""
	var at: int = 0
	while at < line.length():
		var mark: String = line[at]
		if not quote.is_empty():
			if mark == "\\":
				at += 1
			elif mark == quote:
				quote = ""
		elif mark == '"' or mark == "'":
			quote = mark
		elif mark == "#":
			return line.substr(0, at)
		at += 1
	return line


## Where the parenthesis opened at open_at closes, skipping strings; the end of the text
## when it never does.
static func closing(text: String, open_at: int) -> int:
	var depth: int = 0
	var quote: String = ""
	var at: int = open_at
	while at < text.length():
		var mark: String = text[at]
		if not quote.is_empty():
			if mark == "\\":
				at += 1
			elif mark == quote:
				quote = ""
		elif mark == '"' or mark == "'":
			quote = mark
		elif mark == "(":
			depth += 1
		elif mark == ")":
			depth -= 1
			if depth == 0:
				return at
		at += 1
	return text.length()


## Each call matched by call_pattern, which ends at its opening parenthesis, as
## [start, argument start, argument end].
static func calls(text: String, call_pattern: String) -> Array[Vector3i]:
	var found: Array[Vector3i] = []
	for hit: RegExMatch in pattern(call_pattern).search_all(text):
		var open_at: int = hit.get_end() - 1
		found.append(Vector3i(hit.get_start(), open_at + 1, closing(text, open_at)))
	return found


## The text with the arguments of every call matched by call_pattern blanked.
static func blank_calls(text: String, call_pattern: String) -> String:
	var kept: String = text
	var past: int = -1
	for span: Vector3i in calls(text, call_pattern):
		if span.x < past:
			continue
		past = span.z
		kept = blank(kept, span.y, span.z)
	return kept


## The text with from..to turned to spaces, its line breaks kept.
static func blank(text: String, from: int, to: int) -> String:
	var inner: String = pattern("[^\\n]").sub(text.substr(from, to - from), " ", true)
	return text.substr(0, from) + inner + text.substr(to)


static func line_of(text: String, offset: int) -> int:
	return text.substr(0, offset).count("\n") + 1


## True when the literal value has words once BBCode tags and placeholders are out.
static func has_words(value: String) -> bool:
	return pattern("[A-Za-z]").search(pattern(NOT_WORDS).sub(value, " ", true)) != null


static func reads_as_prose(value: String) -> bool:
	return pattern(PROSE).search(pattern(NOT_WORDS).sub(value, " ", true)) != null


## True when value is a key of the table, a key with placeholders that names one, or a
## prefix ending in a dot that at least one key starts with.
static func is_key(value: String, keys: Dictionary[String, bool]) -> bool:
	if keys.has(value):
		return true
	if pattern(KEY_SHAPE).search(value) == null:
		return false
	if value.contains("%"):
		var shape: String = "^" + value.replace(".", "\\.") + "$"
		shape = shape.replace("%s", ".+").replace("%d", "[0-9]+")
		var fits_shape: Callable = func(key: String) -> bool:
			return pattern(shape).search(key) != null
		return _any_key(keys, fits_shape)
	var starts: Callable = func(key: String) -> bool: return key.begins_with(value)
	return value.ends_with(".") and _any_key(keys, starts)


static func _any_key(keys: Dictionary[String, bool], test: Callable) -> bool:
	for key: String in keys:
		if bool(test.call(key)):
			return true
	return false


## The literals in text from..to that are not a dictionary's keys, as [offset, value].
static func literals(text: String, from: int = 0, to: int = -1) -> Array[Array]:
	var found: Array[Array] = []
	var span: String = text.substr(from, (text.length() if to < 0 else to) - from)
	for hit: RegExMatch in pattern(LITERAL).search_all(span):
		var after: String = span.substr(hit.get_end(), 8)
		if pattern(r"^\s*:(?!=)").search(after) != null:
			continue
		var value: String = hit.get_string(1) if hit.get_start(1) >= 0 else hit.get_string(2)
		found.append([from + hit.get_start(), value])
	return found


## A script's code with its developer text, its keys and format()'s names blanked.
static func player_code(text: String) -> String:
	var code: String = blank_calls(code_of(text), DEVELOPER_CALLS)
	code = blank_calls(code, KEY_CALLS)
	return blank_calls(code, FORMAT_CALLS)


## Hard-coded player-facing text in one file: every literal that reaches the player and
## is not a key.
static func text_offences(
	path: String, text: String, keys: Dictionary[String, bool]
) -> PackedStringArray:
	if path.get_extension() != "gd":
		return _property_offences(path, text, keys)
	var code: String = player_code(text)
	var heard: Dictionary[int, String] = {}
	for hit: RegExMatch in pattern(TEXT_ASSIGNED).search_all(code):
		var right: String = _top_level(hit.get_string(1))
		for found: Array in literals(right):
			heard[hit.get_start(1) + int(found[0])] = found[1]
	for span: Vector3i in calls(code, TEXT_CALLS):
		var arguments: String = _top_level(code.substr(span.y, span.z - span.y))
		for found: Array in literals(arguments):
			heard[span.y + int(found[0])] = found[1]
	var offences: PackedStringArray = []
	for at: int in heard:
		if has_words(heard[at]) and not is_key(heard[at], keys):
			offences.append('%s:%d: "%s"' % [path, line_of(code, at), heard[at]])
	for found: Array in literals(code):
		var value: String = found[1]
		if not heard.has(int(found[0])) and reads_as_prose(value) and not is_key(value, keys):
			offences.append('%s:%d: "%s"' % [path, line_of(code, int(found[0])), value])
	return offences


## The text with every parenthesized group blanked, so only its own literals are left:
## an argument naming a field, such as "name", is not what is printed.
static func _top_level(text: String) -> String:
	var kept: String = text
	var at: int = kept.find("(")
	while at >= 0:
		var end: int = closing(kept, at)
		kept = blank(kept, at + 1, end)
		at = kept.find("(", end)
	return kept


static func _property_offences(
	path: String, text: String, keys: Dictionary[String, bool]
) -> PackedStringArray:
	var offences: PackedStringArray = []
	var lines: PackedStringArray = text.split("\n")
	for index: int in lines.size():
		var line: String = lines[index]
		if line.begins_with("["):
			continue
		var shown: RegExMatch = pattern(TEXT_PROPERTY).search(line)
		for found: Array in literals(line):
			var value: String = found[1]
			var printed: bool = shown != null and has_words(value)
			if (printed or reads_as_prose(value)) and not is_key(value, keys):
				offences.append('%s:%d: "%s"' % [path, index + 1, value])
	return offences


## Every literal key handed to tr, TranslationServer.translate or Strings that is not in
## the table. A key built at run time is checked by its literal start, which at least one
## key must begin with, or by its shape with %s or %d, which at least one key must have.
static func key_offences(
	path: String, text: String, keys: Dictionary[String, bool]
) -> PackedStringArray:
	var offences: PackedStringArray = []
	var code: String = code_of(text)
	for span: Vector3i in calls(code, KEY_CALLS.replace("|has", "")):
		var first: String = _first_argument(code.substr(span.y, span.z - span.y))
		var quoted: RegExMatch = pattern('^"([^"]*)"\\s*(.?)').search(first)
		if quoted == null:
			continue
		var key: String = quoted.get_string(1)
		var known: bool = keys.has(key)
		match quoted.get_string(2):
			"+":
				var starts: Callable = func(each: String) -> bool: return each.begins_with(key)
				known = known or _any_key(keys, starts)
			"%":
				known = known or is_key(key, keys)
		if not known:
			offences.append("%s:%d: %s" % [path, line_of(code, span.y), key])
	return offences


## A call's first argument, up to its first comma outside brackets and strings.
static func _first_argument(arguments: String) -> String:
	var depth: int = 0
	var quote: String = ""
	var at: int = 0
	while at < arguments.length():
		var mark: String = arguments[at]
		if not quote.is_empty():
			if mark == "\\":
				at += 1
			elif mark == quote:
				quote = ""
		elif mark == '"' or mark == "'":
			quote = mark
		elif "([{".contains(mark):
			depth += 1
		elif ")]}".contains(mark):
			depth -= 1
		elif mark == "," and depth == 0:
			break
		at += 1
	return arguments.substr(0, at).strip_edges()


## Each line of text holding a Chinese, Japanese or Korean character.
static func cjk_lines(path: String, text: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var lines: PackedStringArray = text.split("\n")
	for index: int in lines.size():
		if pattern(CJK).search(lines[index]) != null:
			found.append("%s:%d" % [path, index + 1])
	return found
