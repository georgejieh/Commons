class_name PerfRow
extends RefCounted
## One row of the budget report: the budget, what was measured, the verdict and how many
## samples stand behind it. A row that was not measured says why and is never a pass.

enum Verdict { PASS, MISS, INFO, NOT_MEASURED }

const NAMES: Array[String] = ["PASS", "MISS", "INFO", "NOT MEASURED"]

var name: String
var budget: String
var measured: String
var verdict: Verdict
var samples: String
var note: String


func _init(
	row_name: String,
	row_budget: String,
	row_measured: String,
	row_verdict: Verdict,
	row_samples: String = "",
	row_note: String = ""
) -> void:
	name = row_name
	budget = row_budget
	measured = row_measured
	verdict = row_verdict
	samples = row_samples
	note = row_note


## A row nothing was measured for.
static func unmeasured(row_name: String, row_budget: String, why: String) -> PerfRow:
	return PerfRow.new(row_name, row_budget, "not measured", Verdict.NOT_MEASURED, "", why)


## PASS when ok, else MISS.
static func judged(
	row_name: String,
	row_budget: String,
	row_measured: String,
	ok: bool,
	row_samples: String,
	row_note: String = ""
) -> PerfRow:
	var verdict_of: Verdict = Verdict.PASS if ok else Verdict.MISS
	return PerfRow.new(row_name, row_budget, row_measured, verdict_of, row_samples, row_note)


func verdict_text() -> String:
	return NAMES[verdict]


func line() -> String:
	return (
		"%s | budget %s | measured %s | %s | samples %s"
		% [name, budget, measured, verdict_text(), samples if not samples.is_empty() else "-"]
	)


func table_line() -> String:
	var shown: String = measured if note.is_empty() else "%s (%s)" % [measured, note]
	return (
		"| %s | %s | %s | %s | %s |"
		% [name, budget, shown.replace("|", "/"), verdict_text(), samples]
	)


## The value at fraction (0 to 1) of the sorted values, by nearest rank. 0 when empty.
static func percentile(sorted: PackedFloat64Array, fraction: float) -> float:
	if sorted.is_empty():
		return 0.0
	return sorted[mini(sorted.size() - 1, int(sorted.size() * fraction))]


static func sorted_of(values: PackedFloat64Array) -> PackedFloat64Array:
	var copy: PackedFloat64Array = values.duplicate()
	copy.sort()
	return copy
