class_name UnlockSheet
extends RefCounted
## One item as a page between runs shows it (ADR 0025): an open item's name and rules, or
## for a locked one only the line saying when it opens. A locked sheet carries nothing
## else, so no view of it can name the item.

var id: String = ""
## The item's place in its list, such as a stake's number.
var index: int = 0
var open: bool = false
var name: String = ""
var text: String = ""
## A Cadre's ID for its art, or empty for an item with none.
var art_id: String = ""
## When a locked item opens, or empty.
var locked_line: String = ""


## An open item's sheet.
static func opened(item_id: String, item_name: String, rules: String) -> UnlockSheet:
	var sheet: UnlockSheet = UnlockSheet.new()
	sheet.id = item_id
	sheet.open = true
	sheet.name = item_name
	sheet.text = rules
	return sheet


## A locked item's sheet: the line alone. Its ID stays empty too.
static func locked(line: String) -> UnlockSheet:
	var sheet: UnlockSheet = UnlockSheet.new()
	sheet.locked_line = line
	return sheet


## "Opens after 1 more run", or after count more runs.
static func runs_line(count: int) -> String:
	if count == 1:
		return TranslationServer.translate("unlock.runs_one")
	return TranslationServer.translate("unlock.runs").format({"count": count})
