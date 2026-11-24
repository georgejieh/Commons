class_name ScoreBreakdown
extends RefCounted
## One play's score and the ordered steps the UI shows. Steps share one flat array of
## kind and value pairs, sized once, so a play costs a single array allocation.

enum Step { CARD_GRAIN, ADD_GRAIN, RATE, RATE_CAP, ADD_ZEAL, MUL_ZEAL }

const VALUES_PER_STEP: int = 2
## Every step but the card steps happens at most once.
const FIXED_STEPS: int = 5

var grain: float = 0.0
var rate: float = 0.0
var zeal: float = 0.0
var total: float = 0.0
## False when a hook waived the Resentment the play's stamped cards add (ADR 0032).
var stamps_resented: bool = true
var steps: PackedFloat64Array = PackedFloat64Array()
var step_count: int = 0
## Every change to the score, one at a time, for the table to act out (P5.2a). Kept only
## when the scorer was asked to record, as for a real play; empty for a preview.
var trail: Array[ScoreStep] = []


func _init(scored_cards: int) -> void:
	steps.resize((scored_cards + FIXED_STEPS) * VALUES_PER_STEP)


func add_step(kind: Step, value: float) -> void:
	steps[step_count * VALUES_PER_STEP] = kind
	steps[step_count * VALUES_PER_STEP + 1] = value
	step_count += 1


func step_kind(index: int) -> Step:
	return int(steps[index * VALUES_PER_STEP]) as Step


func step_value(index: int) -> float:
	return steps[index * VALUES_PER_STEP + 1]
