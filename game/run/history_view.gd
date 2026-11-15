class_name HistoryView
extends RefCounted
## The family's past generations as the village history shows them (ADR 0025): one plain
## line per finished run in the profile's history, newest first, with every string filled
## in. A record only: the generation, the ending's title (a death's page title for a
## death), the class and the Year, then the families that died, joined as the epilogue
## joins names.


## One line per finished run, newest first; empty when none has finished.
static func generations(profile: SaveService) -> PackedStringArray:
	var lines: PackedStringArray = []
	var history: Array[HistoryEntry] = Profile.read(profile).history
	for index: int in range(history.size() - 1, -1, -1):
		lines.append(line(history[index]))
	return lines


## "Generation 3. Lean Years. Peasant. Year 8." and, when families died, "Not at roll
## call: Li and Chen." after it.
static func line(entry: HistoryEntry) -> String:
	var class_key: String = (
		"end.class.landlord" if entry.class_id == HistoryEntry.LANDLORD else "end.class.peasant"
	)
	var values: Dictionary[String, Variant] = {
		"number": entry.generation,
		"ending": _t(Endings.title_key(entry.outcome)),
		"class": _t(class_key),
		"year": entry.year,
	}
	var text: String = _t("hist.generation").format(values)
	if entry.dead.is_empty():
		return text
	var names: PackedStringArray = []
	for name_key: String in entry.dead:
		names.append(_t(name_key))
	return text + " " + _t("hist.not_at_roll_call").format({"names": EndingView.joined(names)})


static func _t(key: String) -> String:
	return str(TranslationServer.translate(key))
