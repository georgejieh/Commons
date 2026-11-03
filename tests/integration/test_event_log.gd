extends GdUnitTestSuite
## A full 24-Set run keeps only the current Set's log, and every Set's summary matches a
## recount of that Set's raw events.

const SEED: int = 3701
const SETS: int = 24
## Set intros before memory is first compared, so caches and pools have filled.
const WARM_UP: int = 4
## One SetSummary per Set is the only growth allowed, with room for engine noise.
const OBJECT_SLACK: int = 10
## Far above one Set's events, far below 24 Sets' worth.
const MAX_SET_EVENTS: int = 2000

var _mismatches: int = 0
var _counted: int = 0
var _log_sizes: PackedInt64Array = []
var _objects: PackedInt64Array = []
var _sets_played: int = 0


func before() -> void:
	var loop: RunLoop = RunLoop.new(RunState.new(SEED), RunScript.bots())
	loop.state.table.assign(["player", "wang", "li"])
	loop.on_boundary = func() -> void: _measure(loop)
	var script: RunScript = RunScript.new()
	loop.start_set()
	while loop.awaiting() != RunLoop.Awaiting.RUN_OVER:
		if loop.awaiting() == RunLoop.Awaiting.SET_OVER:
			_check_set(loop)
			loop.next_set()
		elif not script.act(loop):
			break


func test_the_run_plays_all_24_sets() -> void:
	assert_int(_sets_played).is_equal(SETS)


func test_summaries_match_a_recount_of_each_sets_log() -> void:
	assert_int(_mismatches).is_equal(0)
	assert_int(_counted).is_greater(0)


func test_memory_stays_flat_across_the_run() -> void:
	for size: int in _log_sizes:
		assert_int(size).is_less(MAX_SET_EVENTS)
	var growth: int = _objects[-1] - _objects[WARM_UP]
	assert_int(growth).is_less(SETS + OBJECT_SLACK)


func _check_set(loop: RunLoop) -> void:
	_sets_played += 1
	var expected: SetSummary = _recount(loop.events(), loop.state.table)
	var actual: SetSummary = loop.state.summaries[-1]
	# Asserts here would add gdUnit objects to the count, so mismatches are tallied.
	if actual.set_number != loop.set_number():
		_mismatches += 1
	for family: String in loop.state.table:
		for kind: int in SetSummary.KIND_COUNT:
			var want: int = expected.count(family, kind as SetSummary.Kind)
			if actual.count(family, kind as SetSummary.Kind) != want:
				_mismatches += 1
			_counted += want
	_log_sizes.append(loop.events().size())


## At Set intro the last Set's log is gone, so what is left is the run itself.
func _measure(loop: RunLoop) -> void:
	if loop.flow.state() == RunFlow.State.SET_INTRO:
		_objects.append(int(Performance.get_monitor(Performance.OBJECT_COUNT)))


## Walks the whole Set's log round by round, as ADR 0012 defines each count.
func _recount(events: Array[RunEvent], families: Array[String]) -> SetSummary:
	var summary: SetSummary = SetSummary.new(-1)
	var landlord: int = Seats.NONE
	var holder: int = Seats.NONE
	var fed_pool: bool = false
	for event: RunEvent in events:
		var played: RoundEvent = event.round_event
		if played != null and played.type == RoundEvent.Type.ROUND_STARTED:
			landlord = played.seat
			holder = Seats.NONE
			fed_pool = false
		elif played != null and played.type == RoundEvent.Type.TRICK_WON:
			holder = Seats.NONE
		elif played != null and played.type == RoundEvent.Type.PLAYED:
			var answered: bool = played.seat == RunLoop.PLAYER and holder != Seats.NONE
			if answered and holder != RunLoop.PLAYER:
				var bomb: bool = played.pattern.type in [Pattern.Type.BOMB, Pattern.Type.ROCKET]
				if bomb:
					summary.add(families[holder], SetSummary.Kind.BOMBED)
				if landlord != RunLoop.PLAYER and holder != landlord:
					summary.add(families[holder], SetSummary.Kind.BETRAYED)
			holder = played.seat
		elif event.type == RunEvent.Type.ROUND_SCORED and event.seat == RunLoop.PLAYER:
			fed_pool = landlord != RunLoop.PLAYER and event.amount >= 1.0
		elif event.type == RunEvent.Type.SHARE_PAID and event.seat != RunLoop.PLAYER:
			if fed_pool and event.value > 0:
				summary.add(families[event.seat], SetSummary.Kind.FED)
	return summary
