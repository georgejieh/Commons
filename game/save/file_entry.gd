class_name FileEntry
extends RefCounted
## One entry in the family's file (ADR 0022): an offence the game noticed and acted on.
## Which detector saw it, the run, its generation, the Year and Quota it was in, and the
## figures as corrected, by RunCorrections' names; an offence with no figure to correct,
## such as a broken seal, has none. key names the offence, so the same one, seen again
## on a replay or a second load, is never filed twice.

## The detector that compared the second book with the run's figures.
const BOOK: String = "book"
## The detector that found a save's seal missing or wrong.
const SEAL: String = "seal"
## The detector that found the private ledger holding a number the save does not.
const BAIT: String = "bait"
## Every detector there is; an entry read from a file must name one of them.
const DETECTORS: Array[String] = [BOOK, SEAL, BAIT]

## Which detector saw the offence, one of DETECTORS.
var detector: String = BOOK
## The ID of the run the offence was in.
var run_id: String = ""
## The generation of the run the offence was in.
var generation: int = 0
## The Year the offence was in, from 1, or 0 with no run.
var year: int = 0
## The Quota the offence was in, counted from 0 across the run, or 0 with no run.
var quota: int = 0
## The figures found changed, by name, with the values they were found at, kept within
## their limits; empty for an offence with no figure.
var figures: Dictionary[String, float] = {}
## Names the offence, so the same one seen again is never filed twice.
var key: String = ""


## The entry a saved dictionary holds.
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


## The entry as it is saved in the profile.
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
