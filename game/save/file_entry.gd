class_name FileEntry
extends RefCounted
## One entry in the family's file (ADR 0022): an offence the game noticed and acted on.
## Which detector saw it, the run, its generation, the Year and Quota it was in, and the
## figures as corrected, by RunCorrections' names; an offence with no figure to correct,
## such as a broken seal, has none. key names the offence, so the same one, seen again
## on a replay or a second load, is never filed twice.

## The three ways the game notices (ADR 0022).
const BOOK: String = "book"
const SEAL: String = "seal"
const BAIT: String = "bait"
const DETECTORS: Array[String] = [BOOK, SEAL, BAIT]

var detector: String = BOOK
var run_id: String = ""
var generation: int = 0
## The Year from 1 and the Quota from 0 across the run, or 0 with no run.
var year: int = 0
var quota: int = 0
var figures: Dictionary[String, float] = {}
var key: String = ""


static func from_dict(data: Dictionary) -> FileEntry:
	var entry: FileEntry = FileEntry.new()
	entry.detector = str(data["detector"])
	entry.run_id = str(data["run_id"])
	entry.generation = int(data["generation"])
	entry.year = int(data["year"])
	entry.quota = int(data["quota"])
	var saved: Dictionary = data["figures"]
	for figure: String in saved:
		entry.figures[figure] = float(saved[figure])
	entry.key = str(data["key"])
	return entry


func to_dict() -> Dictionary:
	return {
		"detector": detector,
		"run_id": run_id,
		"generation": generation,
		"year": year,
		"quota": quota,
		"figures": figures.duplicate(),
		"key": key,
	}


## True when value holds every field with the right kind of value.
static func is_valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var data: Dictionary = value
	if not DETECTORS.has(data.get("detector")):
		return false
	if not data.get("run_id") is String or not data.get("key") is String:
		return false
	for count: String in ["generation", "year", "quota"]:
		if not ProfileData.is_count(data.get(count)):
			return false
	if not data.get("figures") is Dictionary:
		return false
	var saved: Dictionary = data["figures"]
	for figure: Variant in saved:
		var number: Variant = saved[figure]
		if not RunCorrections.FIGURES.has(figure) or not (number is int or number is float):
			return false
	return true
