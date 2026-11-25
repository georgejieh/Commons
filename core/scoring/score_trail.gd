class_name ScoreTrail
extends RefCounted
## Records what changed a play's score as the scorer applies it (P5.2a), for the table to
## act out. The stack tells it after each hook; it compares the context with what it saw
## last, so it changes nothing and needs nothing from an effect. The steps run: each
## scored card's printed Grain; the hand's Rate and Zeal's start; the hand's level; each
## card's mark (its Grain, or a Pennant's Zeal) and card hooks, card by card; then each
## play hook in the order it ran, with every figure it moved. A figure's steps follow the
## scorer's own formula over the hooks so far, so applied in order they land on the play's
## final figures. A preview keeps none. The coupons a Surplus card pays come after, from
## the loop (SurplusPay), as steps of their own figure.

const FIGURES: int = 4
## Indexes into a play hook's fields.
const ADD_GRAIN: int = 0
const ADD_ZEAL: int = 1
const MUL_ZEAL: int = 2
const RATE_PERCENT: int = 3
const RATE_CAP: int = 4
const TOTAL_SCALE: int = 5

var steps: Array[ScoreStep] = []

## The card steps after the printed Grain, held until the base is laid out.
var _card_steps: Array[ScoreStep] = []
## The play context's fields after each hook that moved one, with the hook's definition.
var _hooks: Array[Array] = []
var _last: PackedFloat64Array = PackedFloat64Array()
## The Zeal the cards' marks gave the play, in its add_zeal before any hook ran.
var _mark_zeal: float = 0.0


## A scored card's printed Grain.
func card(card_id: int, printed: float) -> void:
	var step: ScoreStep = _add(ScoreStep.Figure.GRAIN, ScoreStep.Source.CARD, printed)
	step.card_id = card_id
	steps.append(step)


## A card's own enhancement raised its Grain by change.
func mark(card_id: int, enhancement_id: String, change: float) -> void:
	if is_zero_approx(change):
		return
	var step: ScoreStep = _add(ScoreStep.Figure.GRAIN, ScoreStep.Source.MARK, change)
	step.card_id = card_id
	step.source_id = enhancement_id
	_card_steps.append(step)


## A card's own enhancement gave its play change Zeal (ADR 0041).
func mark_zeal(card_id: int, enhancement_id: String, change: float) -> void:
	var step: ScoreStep = _add(ScoreStep.Figure.ZEAL, ScoreStep.Source.MARK, change)
	step.card_id = card_id
	step.source_id = enhancement_id
	_card_steps.append(step)
	_mark_zeal += change


## A card hook changed a card's Grain from before to its context's Grain now.
func card_hook(definition: ModifierDef, context: CardContext, before: float) -> void:
	var change: float = context.grain - before
	if is_zero_approx(change):
		return
	var step: ScoreStep = _add(ScoreStep.Figure.GRAIN, ScoreStep.Source.MODIFIER, change)
	step.card_id = context.card.id()
	_card_steps.append(_named(step, definition))


## The play hooks are about to run on context.
func start_play(context: PlayContext) -> void:
	_last = _fields(context)


## A play hook has run: what it moved is kept for finish().
func play_hook(definition: ModifierDef, context: PlayContext) -> void:
	var now: PackedFloat64Array = _fields(context)
	if now != _last:
		_hooks.append([definition, now])
		_last = now


## Lays out every step once the scorer knows the hand's Rate: base_rate at the hand type's
## first level, level_rate at its level now. min_zeal is the data's floor.
func finish(base_rate: float, level_rate: float, min_zeal: float) -> void:
	steps.append(_put(ScoreStep.Figure.RATE, ScoreStep.Source.HAND, base_rate))
	steps.append(_put(ScoreStep.Figure.ZEAL, ScoreStep.Source.START, Scorer.STARTING_ZEAL))
	if level_rate != base_rate:
		steps.append(_add(ScoreStep.Figure.RATE, ScoreStep.Source.LEVEL, level_rate - base_rate))
	steps.append_array(_card_steps)
	var before: PackedFloat64Array = PackedFloat64Array([0.0, _mark_zeal, 1.0, 100.0, INF, 1.0])
	var start_zeal: float = Scorer.STARTING_ZEAL + _mark_zeal
	var running: PackedFloat64Array = PackedFloat64Array([level_rate, start_zeal])
	for hook: Array in _hooks:
		var now: PackedFloat64Array = hook[1]
		for step: ScoreStep in _hook_steps(before, now, level_rate, min_zeal, running):
			steps.append(_named(step, hook[0]))
		before = now
	_chain()


## What one play hook moved, from the fields before it to now. running holds the Rate
## and Zeal so far, and is moved along.
func _hook_steps(
	before: PackedFloat64Array,
	now: PackedFloat64Array,
	level_rate: float,
	min_zeal: float,
	running: PackedFloat64Array
) -> Array[ScoreStep]:
	var made: Array[ScoreStep] = []
	var modifier: ScoreStep.Source = ScoreStep.Source.MODIFIER
	if now[ADD_GRAIN] != before[ADD_GRAIN]:
		made.append(_add(ScoreStep.Figure.GRAIN, modifier, now[ADD_GRAIN] - before[ADD_GRAIN]))
	var rate: float = Scorer.rate_after(level_rate, int(now[RATE_PERCENT]), now[RATE_CAP])
	if rate != running[0]:
		var capped: bool = now[RATE_CAP] != before[RATE_CAP]
		made.append(_moved(ScoreStep.Figure.RATE, running[0], rate, not capped, capped))
		running[0] = rate
	var zeal: float = maxf(min_zeal, (Scorer.STARTING_ZEAL + now[ADD_ZEAL]) * now[MUL_ZEAL])
	if zeal != running[1]:
		var times: bool = now[MUL_ZEAL] != before[MUL_ZEAL]
		made.append(_moved(ScoreStep.Figure.ZEAL, running[1], zeal, times, false))
		running[1] = zeal
	if now[TOTAL_SCALE] != before[TOTAL_SCALE]:
		var scale: Array[float] = [before[TOTAL_SCALE], now[TOTAL_SCALE]]
		made.append(_moved(ScoreStep.Figure.TOTAL, scale[0], scale[1], true, false))
	return made


## Gives every step the figure it started from and the one it left, in order. The Total
## steps start from the product of the final Grain, Rate and Zeal.
func _chain() -> void:
	var running: PackedFloat64Array = PackedFloat64Array()
	running.resize(FIGURES)
	for step: ScoreStep in steps:
		if step.figure >= ScoreStep.Figure.TOTAL:
			continue
		step.before = running[step.figure]
		step.after = ScoreStep.applied(step.op, step.before, step.value)
		running[step.figure] = step.after
	var total: float = running[ScoreStep.Figure.GRAIN] * running[ScoreStep.Figure.RATE]
	total *= running[ScoreStep.Figure.ZEAL]
	for step: ScoreStep in steps:
		if step.figure == ScoreStep.Figure.TOTAL:
			step.before = total
			step.after = ScoreStep.applied(step.op, total, step.value)
			total = step.after


static func _add(figure: ScoreStep.Figure, source: ScoreStep.Source, value: float) -> ScoreStep:
	return ScoreStep.new(figure, source, ScoreStep.Op.ADD, value, 0.0, 0.0)


static func _put(figure: ScoreStep.Figure, source: ScoreStep.Source, value: float) -> ScoreStep:
	return ScoreStep.new(figure, source, ScoreStep.Op.SET, value, 0.0, 0.0)


## A hook moved a figure from before to after: multiplied when it scales the figure, set
## when a cap took hold or nothing was there to scale, else added to.
static func _moved(
	figure: ScoreStep.Figure, before: float, after: float, times: bool, capped: bool
) -> ScoreStep:
	var source: ScoreStep.Source = ScoreStep.Source.MODIFIER
	if capped or (times and is_zero_approx(before)):
		return _put(figure, source, after)
	if times:
		return ScoreStep.new(figure, source, ScoreStep.Op.MUL, after / before, 0.0, 0.0)
	return _add(figure, source, after - before)


static func _named(step: ScoreStep, definition: ModifierDef) -> ScoreStep:
	if definition != null:
		step.source_id = definition.id
		step.modifier_kind = definition.kind
	return step


static func _fields(context: PlayContext) -> PackedFloat64Array:
	return PackedFloat64Array(
		[
			context.add_grain,
			context.add_zeal,
			context.mul_zeal,
			context.rate_percent,
			context.rate_cap,
			context.total_scale
		]
	)
