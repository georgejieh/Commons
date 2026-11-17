extends GdUnitTestSuite
## ADR 0032: a meter and Resentment can fall, each through one path. A fall stops at 0,
## is logged as a rise is with a negative value, and a meter that falls back below mid by
## the table's margin re-arms its setback, which lifts rationing and lets the setback fire
## again on the next rise.

const TABLE: MeterTable = preload("res://data/run/meters.tres")
const RESENTMENT: ResentmentParams = preload("res://data/run/resentment.tres")

var _state: RunState
var _events: Array[RunEvent] = []


func before_test() -> void:
	_state = RunState.new(43)
	_events.clear()


func _lower(source_id: String, amount: int) -> void:
	RunMeters.lower(
		_state, source_id, amount, TABLE, ModifierStack.new(), RunLoop.DEFAULT_PARAMS, 0, _events
	)


func _raise(source_id: String, amount: int) -> void:
	RunMeters.apply_amount(
		_state, source_id, amount, TABLE, ModifierStack.new(), RunLoop.DEFAULT_PARAMS, 0, _events
	)


func _of(type: RunEvent.Type) -> Array[RunEvent]:
	return _events.filter(func(event: RunEvent) -> bool: return event.type == type)


func test_a_fall_lowers_the_meter_and_is_logged_as_a_negative_change() -> void:
	_state.famine = 20
	_lower(RunMeters.CADRE_FAMINE, 6)
	assert_int(_state.famine).is_equal(14)
	var changed: Array[RunEvent] = _of(RunEvent.Type.METER_CHANGED)
	assert_int(changed.size()).is_equal(1)
	assert_int(changed[0].value).is_equal(-6)
	assert_str(changed[0].text).is_equal(RunMeters.FAMINE)


func test_a_fall_stops_at_zero() -> void:
	_state.famine = 4
	_lower(CampaignContext.FAMINE_SOURCE, 6)
	assert_int(_state.famine).is_equal(0)
	assert_int(_of(RunEvent.Type.METER_CHANGED)[0].value).is_equal(-4)
	_lower(CampaignContext.FAMINE_SOURCE, 6)
	assert_int(_state.famine).is_equal(0)
	assert_int(_of(RunEvent.Type.METER_CHANGED)[1].value).is_equal(0)


## Famine rose through mid (50): rationing started. Falling to 46 is not below the margin
## (45), so it holds; falling to 44 lifts it and re-arms the setback, which fires again
## when Famine rises back through mid.
func test_a_meter_that_falls_back_below_its_band_re_arms_its_setback() -> void:
	var bands: MeterBands = TABLE.famine
	_state.famine = bands.mid - 2
	_raise(CampaignContext.FAMINE_SOURCE, 4)
	assert_bool(_state.rationed).is_true()
	assert_bool(_state.famine_armed).is_false()
	_lower(RunMeters.CADRE_FAMINE, _state.famine - (bands.mid - bands.rearm_margin))
	assert_bool(_state.rationed).is_true()
	assert_bool(_state.famine_armed).is_false()
	_lower(RunMeters.CADRE_FAMINE, 1)
	assert_int(_state.famine).is_equal(bands.mid - bands.rearm_margin - 1)
	assert_bool(_state.rationed).is_false()
	assert_bool(_state.famine_armed).is_true()
	var lifted: Array[RunEvent] = _of(RunEvent.Type.SETBACK)
	assert_int(lifted.size()).is_equal(2)
	assert_int(lifted[1].value).is_equal(0)
	_raise(CampaignContext.FAMINE_SOURCE, bands.rearm_margin + 1)
	assert_bool(_state.rationed).is_true()
	assert_int(_of(RunEvent.Type.SETBACK).size()).is_equal(3)


## Denunciation's setback is owed once: a fall re-arms it, and the reeducation already owed
## stays owed.
func test_denunciation_re_arms_and_keeps_an_owed_reeducation() -> void:
	var bands: MeterBands = TABLE.denunciation
	_state.denunciation = bands.mid - 1
	_raise(CampaignContext.DENUNCIATION_SOURCE, 1)
	assert_bool(_state.reeducation_due).is_true()
	_lower(CampaignContext.DENUNCIATION_SOURCE, bands.rearm_margin + 1)
	assert_bool(_state.denunciation_armed).is_true()
	assert_bool(_state.reeducation_due).is_true()


func test_resentment_falls_through_its_one_path_and_never_below_zero() -> void:
	_state.resentment = 5
	Resentment.lower(_state, 3, Resentment.CADRE, RESENTMENT, _events)
	assert_int(_state.resentment).is_equal(2)
	var logged: Array[RunEvent] = _of(RunEvent.Type.RESENTMENT)
	assert_int(logged[0].value).is_equal(-3)
	assert_str(logged[0].text).is_equal(Resentment.CADRE)
	Resentment.lower(_state, 6, Resentment.CAMPAIGN, RESENTMENT, _events)
	assert_int(_state.resentment).is_equal(0)
	assert_int(_of(RunEvent.Type.RESENTMENT)[1].value).is_equal(-2)
	# From 0 nothing falls, so nothing is logged, as a rise at the top logs nothing.
	Resentment.lower(_state, 1, Resentment.CADRE, RESENTMENT, _events)
	assert_int(_of(RunEvent.Type.RESENTMENT).size()).is_equal(2)


## The rows the falls and Self-Criticism's rise move through carry no amount of their own:
## the item's data gives it.
func test_the_new_meter_rows_take_their_amount_from_the_item() -> void:
	for source_id: String in [RunMeters.CADRE_FAMINE, CampaignContext.DENUNCIATION_SOURCE]:
		var row: MeterSource = TABLE.source(source_id)
		assert_object(row).override_failure_message(source_id).is_not_null()
		assert_int(row.amount).is_equal(0)
	assert_str(TABLE.source(RunMeters.CADRE_FAMINE).meter).is_equal(RunMeters.FAMINE)
	var denunciation: MeterSource = TABLE.source(CampaignContext.DENUNCIATION_SOURCE)
	assert_str(denunciation.meter).is_equal(RunMeters.DENUNCIATION)
