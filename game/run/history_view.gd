class_name HistoryView
extends RefCounted
## The family's past generations as the village history shows them (ADR 0025): one plain
## line per finished run in the profile's history, newest first, with every string filled
## in. A record only: the generation, the ending's title (a death's page title for a
## death), the class and the Year, then the families that died, joined as the epilogue
## joins names. The run in progress reads as a record too: one line per family each
## Quota touched, only what happened, in words.

## Each kind of deed in SetSummary.Kind order, by its string key.
const DEEDS: Array[String] = [
	"hist.deed.fed", "hist.deed.bombed", "hist.deed.denounced", "hist.deed.betrayed"
]
## Counts said as words up to three times, then as a number.
const WORDED: int = 3


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


## The run's Quotas as a record: "Quota 1. Wang: fed twice." for each family a Quota
## touched, in the order it was touched, or "Quota 3. Nothing to record." name_of turns a
## family ID into the name to print.
static func run_lines(summaries: Array[SetSummary], name_of: Callable) -> PackedStringArray:
	var lines: PackedStringArray = []
	for summary: SetSummary in summaries:
		var number: int = summary.set_number + 1
		var before: int = lines.size()
		for family: String in summary.counts:
			var deeds: String = deeds_of(summary, family)
			if deeds.is_empty():
				continue
			var values: Dictionary[String, Variant] = {
				"number": number, "name": str(name_of.call(family)), "deeds": deeds
			}
			lines.append(_t("hist.quota_line").format(values))
		if lines.size() == before:
			lines.append(_t("hist.quota_nothing").format({"number": number}))
	return lines


## What a family went through in a Quota, joined plainly: "bombed once, denounced once",
## or "" when nothing happened to it.
static func deeds_of(summary: SetSummary, family: String) -> String:
	var parts: PackedStringArray = []
	for kind: int in DEEDS.size():
		var count: int = summary.count(family, kind as SetSummary.Kind)
		if count > 0:
			parts.append(_t(DEEDS[kind]).format({"times": times(count)}))
	return ", ".join(parts)


## "once", "twice", "three times", then "4 times".
static func times(count: int) -> String:
	if count <= WORDED:
		return _t("hist.times.%d" % count)
	return _t("hist.times.many").format({"count": count})
