class_name RunRequest
extends RefCounted
## What a new run is asked to be (ADR 0025): its kind, seed, household, stake and lineage,
## and whether it writes the profile. The app, the demo, the arrival and the balance
## harness all start runs from one of these, through RunStarter.

## The kind of the demo run.
const DEMO: RunIdentity.Kind = RunIdentity.Kind.DEMO
## The kind of the full run.
const FULL: RunIdentity.Kind = RunIdentity.Kind.FULL
## The arrival (ADR 0026): authored, never saved, and never written to the profile.
const TUTORIAL: RunIdentity.Kind = RunIdentity.Kind.TUTORIAL

## Which kind of run this is: FULL, DEMO or TUTORIAL.
var kind: RunIdentity.Kind = FULL
## The seed every stream of the run is derived from.
var seed_value: int = 0
## Seconds since the epoch when the run starts, which with the seed makes its ID. 0 takes
## the clock's.
var start_time: int = 0
## The household's ID, or empty for none. RunStarter refuses one the profile has not
## unlocked.
var household: String = ""
## The stake, from 0. RunStarter refuses one past the highest the profile has unlocked.
var stake: int = 0
## The kind of lineage a run outside the profile inherits. A run that reads the profile
## takes the profile's lineage instead, so it is never taken twice.
var lineage_kind: String = ""
## The values of that lineage, as its kind defines them.
var lineage_values: Dictionary = {}
## The surname a run outside the profile is named by (ADR 0028); an empty one takes the
## fallback. A run that reads the profile takes the profile's.
var surname: String = ""
## The generation a run outside the profile is named by; 0 names it as the first. A run
## that reads the profile takes the profile's.
var generation: int = 0
## False for a run that must leave the profile as it was, such as the balance harness.
var writes_profile: bool = true
## Every unlock tier, family and stake open, as if no profile limited the run (ADR 0027).
## Only the balance harness sets it, and only for a run that reads no profile: RunStarter
## refuses it with one. No menu reaches it.
var all_open: bool = false


func _init(run_kind: RunIdentity.Kind = FULL, seed_in: int = 0, start: int = 0) -> void:
	kind = run_kind
	seed_value = seed_in
	start_time = start
