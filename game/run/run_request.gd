class_name RunRequest
extends RefCounted
## What a new run is asked to be (ADR 0025): its kind, seed, household, stake and lineage,
## and whether it writes the profile. The app, the demo, the arrival and the balance
## harness all start runs from one of these, through RunStarter.

const DEMO: int = RunIdentity.Kind.DEMO
const FULL: int = RunIdentity.Kind.FULL
## The arrival (ADR 0026): authored, never saved, and never written to the profile.
const TUTORIAL: int = RunIdentity.Kind.TUTORIAL

var kind: int = FULL
var seed_value: int = 0
## Seconds since the epoch when the run starts, which with the seed makes its ID. 0 takes
## the clock's.
var start_time: int = 0
## The household's ID, or empty for none, and the stake, from 0 (ADR 0025). RunStarter
## refuses a household or stake the profile has not unlocked.
var household: String = ""
var stake: int = 0
## The lineage a run outside the profile inherits. A run that reads the profile takes the
## profile's lineage instead, so it is never taken twice.
var lineage_kind: String = ""
var lineage_values: Dictionary = {}
## The surname and generation a run outside the profile is named by (ADR 0028); an empty
## surname takes the fallback, and generation 0 names it as the first. A run that reads
## the profile takes the profile's.
var surname: String = ""
var generation: int = 0
## False for a run that must leave the profile as it was, such as the balance harness.
var writes_profile: bool = true
## Every unlock tier, family and stake open, as if no profile limited the run (ADR 0027).
## Only the balance harness sets it, and only for a run that reads no profile: RunStarter
## refuses it with one. No menu reaches it.
var all_open: bool = false


func _init(run_kind: int = FULL, seed_in: int = 0, start: int = 0) -> void:
	kind = run_kind
	seed_value = seed_in
	start_time = start
