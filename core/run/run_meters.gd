class_name RunMeters
extends RefCounted
## Moves Famine and Denunciation by a named source from the meter table, through the
## meter change hook, and applies their mid-band setbacks. Rationing (Famine) holds while
## the meter stays up; reeducation (Denunciation) is owed once and served after the Set.
## Each setback fires once per upward crossing of mid, then re-arms below the margin.

## The Famine meter's name, as the table, the events and the state use it.
const FAMINE: String = "famine"
## The Denunciation meter's name, as the table, the events and the state use it.
const DENUNCIATION: String = "denunciation"
## The source for Famine when a Quota's target is missed.
const MISSED_TARGET: String = "missed_target"
## The source for Famine when a round's share to the commons falls short.
const COMMONS_SHORTFALL: String = "commons_shortfall"
## The source for Denunciation when the player buys at the black market.
const PRIVATE_PURCHASE: String = "private_purchase"
## The source for Denunciation when an audit catches the player's declared need false.
const CAUGHT_LIE: String = "caught_lie"
## A Set in a run of Sets the player never held the landlord's seat in (ADR 0031). Its
## amount is for each step of the run past the grace.
const STOOD_BY: String = "stood_by"
## Famine a held Cadre takes off; its amount is the Cadre's (Public Granary, ADR 0032).
const CADRE_FAMINE: String = "cadre_famine"
## The source for Famine that a debuff raises when a round is lost.
const DEBUFF_FAMINE: String = "debuff_famine"
## The source for Denunciation that a debuff raises when a round is lost.
const DEBUFF_DENUNCIATION: String = "debuff_denunciation"
## Its amount comes from the Resentment curve, not the row.
const RESENTMENT: String = "resentment"
## The setback Famine causes in its mid band; it holds while the meter stays up.
const RATIONING: String = "rationing"
## The setback Denunciation causes in its mid band, owed once and served after the Set.
const REEDUCATION: String = "reeducation"


## Applies the source's row, then any setback it causes.
static func apply(
	state: RunState,
	source_id: String,
	table: MeterTable,
	stack: ModifierStack,
	params: RunParams,
	player: int,
	events: Array[RunEvent]
) -> void:
	var source: MeterSource = table.source(source_id)
	assert(source != null, "Unknown meter source")
	apply_amount(state, source_id, source.amount, table, stack, params, player, events)


## Applies the source's meter by an amount worked out elsewhere, such as a curve.
static func apply_amount(
	state: RunState,
	source_id: String,
	amount: int,
	table: MeterTable,
	stack: ModifierStack,
	params: RunParams,
	player: int,
	events: Array[RunEvent]
) -> void:
	var source: MeterSource = table.source(source_id)
	var context: MeterContext = MeterContext.new(source.meter, amount)
	stack.run_meter_change(context)
	var before: int = value(state, source.meter)
	var after: int = clampi(before + context.delta, 0, params.meter_max)
	_set_value(state, source.meter, after)
	events.append(
		RunEvent.new(RunEvent.Type.METER_CHANGED, player, after - before, 0.0, source.meter)
	)
	_update_setbacks(state, source.meter, table.bands(source.meter), player, events)


## Lowers the source's meter by amount, the one path a meter falls by (ADR 0032): through
## the meter change hook as a rise goes, never below 0, logged as METER_CHANGED with the
## fall as a negative value, and re-arming the band's setback once the meter is back below
## mid by the table's margin, which lifts rationing.
static func lower(
	state: RunState,
	source_id: String,
	amount: int,
	table: MeterTable,
	stack: ModifierStack,
	params: RunParams,
	player: int,
	events: Array[RunEvent]
) -> void:
	assert(amount >= 0, "A fall is given as a positive amount")
	apply_amount(state, source_id, -amount, table, stack, params, player, events)


## Sets a meter to a figure reported from outside the game (ADR 0022). No hook runs, since
## nothing in the run moved it, but the bands and setbacks follow as for any rise.
static func report(
	state: RunState,
	meter: String,
	amount: int,
	table: MeterTable,
	params: RunParams,
	player: int,
	events: Array[RunEvent]
) -> void:
	var before: int = value(state, meter)
	var after: int = clampi(amount, 0, params.meter_max)
	_set_value(state, meter, after)
	events.append(RunEvent.new(RunEvent.Type.METER_CHANGED, player, after - before, 0.0, meter))
	_update_setbacks(state, meter, table.bands(meter), player, events)


## The state's value of the meter, FAMINE or DENUNCIATION.
static func value(state: RunState, meter: String) -> int:
	return state.famine if meter == FAMINE else state.denunciation


## True once either meter reaches its death threshold.
static func dead(state: RunState, table: MeterTable) -> bool:
	return state.famine >= table.famine.death or state.denunciation >= table.denunciation.death


static func _set_value(state: RunState, meter: String, amount: int) -> void:
	if meter == FAMINE:
		state.famine = amount
	else:
		state.denunciation = amount


static func _update_setbacks(
	state: RunState, meter: String, bands: MeterBands, player: int, events: Array[RunEvent]
) -> void:
	var now: int = value(state, meter)
	var armed: bool = state.famine_armed if meter == FAMINE else state.denunciation_armed
	if armed and now >= bands.mid:
		armed = false
		if meter == FAMINE:
			state.rationed = true
		else:
			state.reeducation_due = true
		var setback: String = RATIONING if meter == FAMINE else REEDUCATION
		events.append(RunEvent.new(RunEvent.Type.SETBACK, player, 1, 0.0, setback))
	elif not armed and bands.rearms_at(now):
		armed = true
		if meter == FAMINE and state.rationed:
			state.rationed = false
			events.append(RunEvent.new(RunEvent.Type.SETBACK, player, 0, 0.0, RATIONING))
	if meter == FAMINE:
		state.famine_armed = armed
	else:
		state.denunciation_armed = armed
