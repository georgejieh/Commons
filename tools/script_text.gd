class_name ScriptText
extends RefCounted
## GDScript source as the text scans read it, so the tools' checks and the tests' scans
## tell code from comments one way. Development only; tools/ never ships.


## A script's text with every comment cut from its line, so each line keeps its number. A
## hash inside a string literal belongs to the string.
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
