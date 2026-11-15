extends GdUnitTestSuite
## ADR 0025: the Anonymous Letter is the player's denunciation. The family it forces to
## pass, teammate or opponent, is denounced; a wasted Letter denounces nobody; and the
## memory weighs the denunciation.

const MEMORY: MemoryParams = preload("res://data/villagers/memory.tres")
const FAMILIES: Array[String] = ["player", "li", "chen"]


## One round with the landlord in seat landlord and a Letter's result at the end.
func _round(landlord: int, letter: RunEvent) -> Array[RunEvent]:
	var events: Array[RunEvent] = [
		RunEvent.wrap(RoundEvent.new(RoundEvent.Type.ROUND_STARTED, landlord)),
		RunEvent.new(RunEvent.Type.CAMPAIGN_USED, 0, 0, 0.0, "anonymous_letter"),
	]
	events.append(letter)
	return events


func _fold(events: Array[RunEvent]) -> SetSummary:
	var summary: SetSummary = SetSummary.new(0)
	SummaryFold.fold_round(summary, events, 0, FAMILIES)
	return summary


func test_the_forced_opponent_is_denounced() -> void:
	# The player is a peasant with chen; li holds the landlord seat and is forced.
	var summary: SetSummary = _fold(_round(1, RunEvent.new(RunEvent.Type.PASS_FORCED, 1)))
	assert_int(summary.count("li", SetSummary.Kind.DENOUNCED)).is_equal(1)
	assert_int(summary.count("chen", SetSummary.Kind.DENOUNCED)).is_equal(0)


func test_the_forced_teammate_is_denounced_too() -> void:
	# li holds the landlord seat; chen is the player's teammate and is forced.
	var summary: SetSummary = _fold(_round(1, RunEvent.new(RunEvent.Type.PASS_FORCED, 2)))
	assert_int(summary.count("chen", SetSummary.Kind.DENOUNCED)).is_equal(1)
	assert_int(summary.count("li", SetSummary.Kind.DENOUNCED)).is_equal(0)


func test_a_wasted_letter_denounces_nobody() -> void:
	var summary: SetSummary = _fold(_round(0, RunEvent.new(RunEvent.Type.LETTER_LAPSED, 1)))
	for family: String in FAMILIES:
		assert_int(summary.count(family, SetSummary.Kind.DENOUNCED)).is_equal(0)


## Being caught lying at audit is the village's business, not the player's denunciation.
func test_an_audit_alone_denounces_nobody() -> void:
	var caught: RunEvent = RunEvent.new(RunEvent.Type.AUDITED, 1, 1)
	var summary: SetSummary = _fold(_round(0, caught))
	assert_int(summary.count("li", SetSummary.Kind.DENOUNCED)).is_equal(0)


func test_the_memory_weighs_a_denunciation() -> void:
	var summary: SetSummary = _fold(_round(1, RunEvent.new(RunEvent.Type.PASS_FORCED, 1)))
	var memory: VillageMemory = VillageMemory.new()
	memory.record(summary)
	assert_float(memory.grudge("li", MEMORY)).is_equal(MEMORY.denounced_weight)
	assert_float(memory.pull("li", MEMORY)).is_equal_approx(
		MEMORY.denounced_weight / MEMORY.full_grudge, 0.0001
	)
