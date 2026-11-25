class_name ScoreStep
extends RefCounted
## One change to a play's score, as plain data: a card counted for Grain, the hand
## type's Rate, Zeal's start, a Directive's level, a card's mark, or a modifier's hook. A
## play's steps, taken in order and applied to each figure, give its Grain, Rate and Zeal,
## and the product of those three, with the Total steps applied, gives its total. The table
## acts them out one at a time.

## COUPONS is what a Surplus card paid the player (ADR 0041): never part of the score, so
## it changes no other figure.
enum Figure { GRAIN, RATE, ZEAL, TOTAL, COUPONS }
## CARD is a scored card's printed Grain; HAND the hand type's Rate at its first level;
## START Zeal before any hook; LEVEL what the hand type's level adds to its Rate; MARK a
## card's own enhancement, for its Grain, its play's Zeal or the coupons it paid;
## MODIFIER a held Cadre, a debuff, a Reform or a boss twist.
enum Source { CARD, HAND, START, LEVEL, MARK, MODIFIER }
## ADD adds value to the figure, MUL multiplies it by value, SET makes it value.
enum Op { ADD, MUL, SET }

var figure: Figure
var source: Source
var op: Op
var value: float
## The figure before and after this step.
var before: float
var after: float
## The modifier or enhancement that made the change, or "" for none.
var source_id: String = ""
## The modifier's ModifierDef.Kind, or -1 when the step is not a modifier's.
var modifier_kind: int = -1
## The card the step scored on, or -1 when it was the play's.
var card_id: int = -1


func _init(
	figure_value: Figure,
	source_value: Source,
	op_value: Op,
	value_value: float,
	before_value: float,
	after_value: float
) -> void:
	figure = figure_value
	source = source_value
	op = op_value
	value = value_value
	before = before_value
	after = after_value


## The figure a step leaves when applied to before.
static func applied(step_op: Op, from: float, by: float) -> float:
	match step_op:
		Op.ADD:
			return from + by
		Op.MUL:
			return from * by
	return by


## True when the step lowered its figure, as a debuff that cuts the score does.
func is_cut() -> bool:
	return after < before
