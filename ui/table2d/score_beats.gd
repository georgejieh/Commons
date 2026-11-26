class_name ScoreBeats
extends RefCounted
## The timing of a scored play acted out: one beat per step of the play's score,
## then the total's roll and stamp. The cards tick quicker as they go, and so do the steps
## that change the score after the first, each to score_quicken of the one before but
## never under its least; the whole stays within score_most, so a ten-step chain never
## takes ten times one step. Pace scales the lot. Pure: it only reads the presets.

enum Kind { ENTER, TICK, RATE, ZEAL, STEP, ROLL, STAMP }

const PRESETS: MotionPresets = preload("res://data/ui/motion_presets.tres")

## Each beat's kind, the step it shows (-1 for none) and its seconds, in order.
var kinds: Array[Kind] = []
var step_index: Array[int] = []
var seconds: Array[float] = []


## Lays out the beats for steps at pace, where 1 is the player's own play at Standard.
static func lay_out(steps: Array[ScoreStep], pace: float) -> ScoreBeats:
	var beats: ScoreBeats = ScoreBeats.new()
	beats._add(Kind.ENTER, -1, PRESETS.score_enter)
	var ticks: int = 0
	var changes: int = 0
	for index: int in steps.size():
		var step: ScoreStep = steps[index]
		match step.source:
			ScoreStep.Source.CARD:
				var tick: float = PRESETS.score_tick * pow(PRESETS.score_quicken, ticks)
				beats._add(Kind.TICK, index, maxf(PRESETS.score_least_tick, tick))
				ticks += 1
			ScoreStep.Source.HAND:
				beats._add(Kind.RATE, index, PRESETS.score_land)
			ScoreStep.Source.START:
				beats._add(Kind.ZEAL, index, PRESETS.score_land)
			_:
				var each: float = PRESETS.score_step * pow(PRESETS.score_quicken, changes)
				beats._add(Kind.STEP, index, maxf(PRESETS.score_least_step, each))
				changes += 1
	beats._add(Kind.ROLL, -1, PRESETS.score_roll)
	beats._add(Kind.STAMP, -1, PRESETS.score_stamp)
	var whole: float = beats.total()
	var fit: float = minf(1.0, PRESETS.score_most / whole) if whole > 0.0 else 1.0
	for index: int in beats.seconds.size():
		beats.seconds[index] *= fit * pace
	return beats


## Seconds from the first beat to the end of the stamp.
func total() -> float:
	var sum: float = 0.0
	for each: float in seconds:
		sum += each
	return sum


## Semitones the nth tick or chime of a play climbs, or a cut falls, from the first.
static func semitones(order: int) -> int:
	var ladder: Array[int] = PRESETS.score_scale_steps
	if ladder.is_empty():
		return 0
	return ladder[clampi(order, 0, ladder.size() - 1)]


func _add(kind: Kind, index: int, each: float) -> void:
	kinds.append(kind)
	step_index.append(index)
	seconds.append(each)
