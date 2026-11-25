extends GdUnitTestSuite
## The village history's lines for the run in progress read the same after a save is
## loaded as they did live (ADR 0025): each Quota's families in roster order, though the
## save writes a Quota's families in name order.

const SEEDS: Array[int] = [6610, 6611, 6612, 6613]
const QUOTAS: int = 3


func _name_of(family: String) -> String:
	return family


## Plays QUOTAS Quotas of a run that seats the village, passing through each shop.
func _played(seed_value: int) -> RunLoop:
	var state: RunState = RunState.new(seed_value)
	Roster.start(state, RunLoop.DEFAULT_VILLAGE, [])
	var loop: RunLoop = RunLoop.new(state, RunScript.bots(), SetConfig.new())
	loop.start_set()
	for quota: int in QUOTAS:
		RunScript.new().play_until_set_over(loop)
		if quota < QUOTAS - 1:
			loop.open_shop()
			RunScript.next_set(loop)
	return loop


func test_a_loaded_run_lists_each_quotas_families_as_the_live_run_did() -> void:
	var several: int = 0
	for seed_value: int in SEEDS:
		var loop: RunLoop = _played(seed_value)
		assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.SET_OVER)
		var saved: Dictionary = JSON.parse_string(JSON.stringify(loop.record.to_dict()))
		var resumed: RunLoop = RunRecord.resume(saved, RunScript.bots())
		assert_object(resumed).is_not_null()
		var live: PackedStringArray = HistoryView.run_lines(loop.state, _name_of)
		var loaded: PackedStringArray = HistoryView.run_lines(resumed.state, _name_of)
		assert_array(Array(loaded)).is_equal(Array(live))
		for summary: SetSummary in loop.state.summaries:
			several += 1 if summary.counts.size() > 1 else 0
	# The order is only tested where a Quota touched more than one family.
	assert_int(several).is_greater(0)
