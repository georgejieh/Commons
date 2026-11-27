extends GdUnitTestSuite
## P4.1: every meter source moves its meter by its table row, mid-band setbacks fire once
## per upward crossing with hysteresis, and either meter's death threshold is death.

const TABLE: MeterTable = preload("res://data/run/meters.tres")


## Halves every meter change, as a softening Cadre would.
class Halve:
	extends ModifierEffect

	func meter_change(context: MeterContext) -> void:
		@warning_ignore("integer_division")
		context.delta = context.delta / 2


var _state: RunState
var _events: Array[RunEvent] = []


func before_test() -> void:
	_state = RunState.new(41)
	_events.clear()


func _apply(source_id: String) -> void:
	RunMeters.apply(
		_state, source_id, TABLE, ModifierStack.new(), RunLoop.DEFAULT_PARAMS, 0, _events
	)


func _setbacks(name: String) -> Array[RunEvent]:
	return _events.filter(
		func(event: RunEvent) -> bool:
			return event.type == RunEvent.Type.SETBACK and event.text == name
	)


func _check_source(source_id: String, meter: String) -> void:
	var row: MeterSource = TABLE.source(source_id)
	assert_object(row).is_not_null()
	assert_str(row.meter).is_equal(meter)
	assert_int(row.amount).is_greater(0)
	_apply(source_id)
	assert_int(RunMeters.value(_state, meter)).is_equal(row.amount)
	var other: String = RunMeters.DENUNCIATION if meter == RunMeters.FAMINE else RunMeters.FAMINE
	assert_int(RunMeters.value(_state, other)).is_equal(0)
	assert_int(_events[0].type).is_equal(RunEvent.Type.METER_CHANGED)
	assert_int(_events[0].value).is_equal(row.amount)
	assert_str(_events[0].text).is_equal(meter)


func test_missed_target_raises_famine() -> void:
	_check_source(RunMeters.MISSED_TARGET, RunMeters.FAMINE)


func test_commons_shortfall_raises_famine() -> void:
	_check_source(RunMeters.COMMONS_SHORTFALL, RunMeters.FAMINE)


func test_private_purchase_raises_denunciation() -> void:
	_check_source(RunMeters.PRIVATE_PURCHASE, RunMeters.DENUNCIATION)


func test_caught_lie_raises_denunciation() -> void:
	_check_source(RunMeters.CAUGHT_LIE, RunMeters.DENUNCIATION)


func test_famine_debuff_raises_famine_by_a_band() -> void:
	_check_source(RunMeters.DEBUFF_FAMINE, RunMeters.FAMINE)
	assert_int(_state.famine).is_equal(TABLE.famine.mid - TABLE.famine.low)


func test_denunciation_debuff_raises_denunciation_by_a_band() -> void:
	_check_source(RunMeters.DEBUFF_DENUNCIATION, RunMeters.DENUNCIATION)
	assert_int(_state.denunciation).is_equal(TABLE.denunciation.mid - TABLE.denunciation.low)


func test_meters_clamp_to_their_range() -> void:
	for index: int in 10:
		_apply(RunMeters.DEBUFF_FAMINE)
	assert_int(_state.famine).is_equal(RunLoop.DEFAULT_PARAMS.meter_max)


func test_rationing_starts_once_per_crossing_and_lifts_below_the_margin() -> void:
	_state.famine = TABLE.famine.mid - 1
	_apply(RunMeters.MISSED_TARGET)
	assert_bool(_state.rationed).is_true()
	_apply(RunMeters.MISSED_TARGET)
	_apply(RunMeters.DEBUFF_FAMINE)
	assert_int(_setbacks(RunMeters.RATIONING).size()).is_equal(1)
	# Dropping to just under mid stays inside the margin: rationing holds.
	_state.famine = TABLE.famine.mid
	_state.famine_armed = false
	_state.famine -= 1
	_apply_lowering(RunMeters.FAMINE, 0)
	assert_bool(_state.rationed).is_true()
	_apply_lowering(RunMeters.FAMINE, -TABLE.famine.rearm_margin)
	assert_bool(_state.rationed).is_false()
	assert_int(_setbacks(RunMeters.RATIONING).size()).is_equal(2)
	assert_int(_setbacks(RunMeters.RATIONING)[1].value).is_equal(0)
	_apply(RunMeters.DEBUFF_FAMINE)
	assert_bool(_state.rationed).is_true()
	assert_int(_setbacks(RunMeters.RATIONING).size()).is_equal(3)


func test_hovering_at_mid_triggers_reeducation_once() -> void:
	_state.denunciation = TABLE.denunciation.mid - 1
	_apply(RunMeters.PRIVATE_PURCHASE)
	assert_bool(_state.reeducation_due).is_true()
	_state.reeducation_due = false
	for index: int in 4:
		_apply_lowering(RunMeters.DENUNCIATION, -2)
		_apply(RunMeters.PRIVATE_PURCHASE)
	assert_int(_setbacks(RunMeters.REEDUCATION).size()).is_equal(1)
	assert_bool(_state.reeducation_due).is_false()


func test_reeducation_rearms_after_falling_below_the_margin() -> void:
	_state.denunciation = TABLE.denunciation.mid - 1
	_apply(RunMeters.PRIVATE_PURCHASE)
	_state.reeducation_due = false
	_apply_lowering(RunMeters.DENUNCIATION, -_state.denunciation)
	_apply(RunMeters.DEBUFF_DENUNCIATION)
	_apply(RunMeters.DEBUFF_DENUNCIATION)
	assert_int(_setbacks(RunMeters.REEDUCATION).size()).is_equal(2)
	assert_bool(_state.reeducation_due).is_true()


func test_the_meter_change_hook_edits_the_delta() -> void:
	var stack: ModifierStack = ModifierStack.new()
	var definition: ModifierDef = ModifierDef.new()
	definition.kind = ModifierDef.Kind.CADRE
	definition.hooks.assign([Hooks.METER_CHANGE])
	stack.add_entry(ActiveModifier.new(definition, Halve.new()))
	RunMeters.apply(_state, RunMeters.CAUGHT_LIE, TABLE, stack, RunLoop.DEFAULT_PARAMS, 0, _events)
	@warning_ignore("integer_division")
	var halved: int = TABLE.source(RunMeters.CAUGHT_LIE).amount / 2
	assert_int(_state.denunciation).is_equal(halved)


func test_either_meter_at_death_is_death() -> void:
	assert_bool(RunMeters.dead(_state, TABLE)).is_false()
	_state.famine = TABLE.famine.death
	assert_bool(RunMeters.dead(_state, TABLE)).is_true()
	_state.famine = TABLE.famine.death - 1
	_state.denunciation = TABLE.denunciation.death
	assert_bool(RunMeters.dead(_state, TABLE)).is_true()


func test_bands_follow_the_thresholds() -> void:
	var bands: MeterBands = TABLE.famine
	assert_int(bands.band(bands.low - 1)).is_equal(MeterBands.Band.CALM)
	assert_int(bands.band(bands.low)).is_equal(MeterBands.Band.LOW)
	assert_int(bands.band(bands.mid)).is_equal(MeterBands.Band.MID)
	assert_int(bands.band(bands.high)).is_equal(MeterBands.Band.HIGH)
	assert_int(bands.band(bands.death)).is_equal(MeterBands.Band.DEATH)


## Lowers a meter through a one-off source row, as a future relief source would.
func _apply_lowering(meter: String, amount: int) -> void:
	var table: MeterTable = MeterTable.new()
	table.famine = TABLE.famine
	table.denunciation = TABLE.denunciation
	var row: MeterSource = MeterSource.new()
	row.id = "relief"
	row.meter = meter
	row.amount = amount
	table.sources.assign([row])
	var stack: ModifierStack = ModifierStack.new()
	RunMeters.apply(_state, "relief", table, stack, RunLoop.DEFAULT_PARAMS, 0, _events)


func test_a_pool_below_the_declared_needs_is_a_commons_shortfall() -> void:
	_state.landlord_seat = 1
	_state.commons_pool = 10
	var configs: Array[BotConfig] = RunScript.bots()
	var params: RunParams = RunLoop.DEFAULT_PARAMS
	assert_bool(RoundBanking.split(_state, 0, 50, configs, params, _events)).is_true()
	_state.commons_pool = 100000
	assert_bool(RoundBanking.split(_state, 0, 50, configs, params, _events)).is_false()
