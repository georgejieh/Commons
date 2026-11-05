class_name RunMeters
extends RefCounted
## Moves Famine and Denunciation by a named source from the meter table, through the
## meter change hook, and applies their mid-band setbacks. Rationing (Famine) holds while
## the meter stays up; reeducation (Denunciation) is owed once and served after the Set.
## Each setback fires once per upward crossing of mid, then re-arms below the margin.

const FAMINE: String = "famine"
const DENUNCIATION: String = "denunciation"
const MISSED_TARGET: String = "missed_target"
const COMMONS_SHORTFALL: String = "commons_shortfall"
const PRIVATE_PURCHASE: String = "private_purchase"
const CAUGHT_LIE: String = "caught_lie"
const DEBUFF_FAMINE: String = "debuff_famine"
const DEBUFF_DENUNCIATION: String = "debuff_denunciation"
const RATIONING: String = "rationing"
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
	var context: MeterContext = MeterContext.new(source.meter, source.amount)
	stack.run_meter_change(context)
	var before: int = value(state, source.meter)
	var after: int = clampi(before + context.delta, 0, params.meter_max)
	_set_value(state, source.meter, after)
	events.append(
		RunEvent.new(RunEvent.Type.METER_CHANGED, player, after - before, 0.0, source.meter)
	)
	_update_setbacks(state, source.meter, table.bands(source.meter), player, events)


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
