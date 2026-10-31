class_name ScoreBreakdown
extends RefCounted
## One play's score and the ordered steps the UI shows. Steps share one flat array of
## kind and value pairs, sized once, so a play costs a single array allocation.

enum Step { BASE_GRAIN, CARD_GRAIN, ADD_GRAIN, BASE_ZEAL, ADD_ZEAL, MUL_ZEAL, BOMB_ZEAL }

const VALUES_PER_STEP: int = 2
## Every step but the card steps happens at most once.
const FIXED_STEPS: int = 6

var grain: float = 0.0
var zeal: float = 0.0
var total: float = 0.0
var steps: PackedFloat64Array = PackedFloat64Array()
var step_count: int = 0
## Counts how many times the step array was sized.
var allocations: int = 0


func _init(scored_cards: int) -> void:
	steps.resize((scored_cards + FIXED_STEPS) * VALUES_PER_STEP)
	allocations += 1


func add_step(kind: Step, value: float) -> void:
	steps[step_count * VALUES_PER_STEP] = kind
	steps[step_count * VALUES_PER_STEP + 1] = value
	step_count += 1


func step_kind(index: int) -> Step:
	return int(steps[index * VALUES_PER_STEP]) as Step


func step_value(index: int) -> float:
	return steps[index * VALUES_PER_STEP + 1]
