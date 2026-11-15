class_name RunRequest
extends RefCounted
## What a new run is asked to be (ADR 0025): its kind, seed, household, stake and lineage,
## and whether it writes the profile. The app, the demo, and later the tutorial and the
## balance harness all start runs from one of these, through RunStarter.

const DEMO: int = RunIdentity.Kind.DEMO
const FULL: int = RunIdentity.Kind.FULL

var kind: int = FULL
var seed_value: int = 0
## Seconds since the epoch when the run starts, which with the seed makes its ID. 0 takes
## the clock's.
var start_time: int = 0
## Empty or 0 until households, stakes and lineage arrive (ADR 0025, step 4).
var household: String = ""
var stake: int = 0
var lineage_kind: String = ""
var lineage_values: Dictionary = {}
## False for a run that must leave the profile as it was, such as the balance harness.
var writes_profile: bool = true


func _init(run_kind: int = FULL, seed_in: int = 0, start: int = 0) -> void:
	kind = run_kind
	seed_value = seed_in
	start_time = start
