class_name RunMeters
extends RefCounted
## Moves a meter through the meter change hook and keeps it in range.

const FAMINE: String = "famine"


static func raise_famine(
	state: RunState,
	delta: int,
	stack: ModifierStack,
	params: RunParams,
	player: int,
	events: Array[RunEvent]
) -> void:
	var context: MeterContext = MeterContext.new(FAMINE, delta)
	stack.run_meter_change(context)
	var before: int = state.famine
	state.famine = clampi(state.famine + context.delta, 0, params.meter_max)
	events.append(
		RunEvent.new(RunEvent.Type.METER_CHANGED, player, state.famine - before, 0.0, FAMINE)
	)
