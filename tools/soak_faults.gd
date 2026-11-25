class_name SoakFaults
extends RefCounted
## What the soak counts against a run (ADR 0037). A run is sound when every count is 0.

const NAMES: Array[String] = [
	"refused commands",
	"refused bot actions",
	"script and engine errors",
	"save failures",
	"load failures",
	"mismatches after a resume",
]

var refused_commands: int = 0
var bot_actions: int = 0
var errors: int = 0
var save_failures: int = 0
var load_failures: int = 0
var mismatches: int = 0


## The counts in the order NAMES gives them.
func counts() -> Array[int]:
	return [refused_commands, bot_actions, errors, save_failures, load_failures, mismatches]


func total() -> int:
	var sum: int = 0
	for count: int in counts():
		sum += count
	return sum


func add(other: SoakFaults) -> void:
	refused_commands += other.refused_commands
	bot_actions += other.bot_actions
	errors += other.errors
	save_failures += other.save_failures
	load_failures += other.load_failures
	mismatches += other.mismatches
