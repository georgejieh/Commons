class_name BooksNoticeText
extends RefCounted
## What the state's notice says when the books were corrected (ADR 0022), built from the
## BOOKS_CORRECTED event alone, every string filled in: the heading, the congratulation,
## one plain line a figure and what followed, and that a note went into the household's
## file. A figure that is dark never has its true value printed: its line gives only the
## value reported. A broken seal, with nothing corrected, has its own short text.

const NAME: String = "notice.name.%s"

var eyebrow: String = ""
var title: String = ""
var body: String = ""
var lines: PackedStringArray = []
var filed: String = ""


## The notice for a correction. dark lists the figures the run shows as dark now, so a
## figure dark before this correction keeps its true value unprinted too.
static func of(correction: BooksCorrection, dark: Array[String]) -> BooksNoticeText:
	var text: BooksNoticeText = BooksNoticeText.new()
	text.eyebrow = _t("notice.eyebrow")
	text.filed = _t("notice.filed")
	if correction == null or correction.is_empty():
		text.title = _t("notice.seal.title")
		text.body = _t("notice.seal.body")
		return text
	text.title = _t("notice.title")
	text.body = _t("notice.body")
	for index: int in correction.figures.size():
		var figure: String = correction.figures[index]
		var reported: float = correction.reported[index]
		if dark.has(figure) or correction.dark.has(figure):
			var key: String = "notice.dark.norm" if figure == ShownFigures.NORM else "notice.dark"
			var values: Dictionary = {"name": _name(figure), "reported": _value(figure, reported)}
			text.lines.append(_t(key).format(values))
			continue
		var line: Dictionary = {
			"name": _name(figure),
			"recorded": _value(figure, correction.true_values[index]),
			"entered": _value(figure, reported),
		}
		text.lines.append(_t("notice.figure").format(line))
	if correction.norm_added > 0:
		text.lines.append(_t("notice.norm").format({"percent": correction.norm_added}))
	if correction.price_added > 0:
		text.lines.append(_t("notice.prices").format({"percent": correction.price_added}))
	return text


## Every line of the notice in reading order, for logs and tests.
func all_lines() -> PackedStringArray:
	var every: PackedStringArray = [eyebrow, title, body]
	every.append_array(lines)
	every.append(filed)
	return every


static func _name(figure: String) -> String:
	return _t(NAME % figure)


## Progress as a score; every other figure is a whole number.
static func _value(figure: String, value: float) -> String:
	if figure == ShownFigures.PROGRESS:
		return Strings.score(value)
	return str(roundi(value))


static func _t(key: String) -> String:
	return str(TranslationServer.translate(key))
