extends GdUnitTestSuite
## The run moves only along its transition table, and the documented diagram matches it.

const ARCHITECTURE: String = "res://docs/ARCHITECTURE.md"
const DIAGRAM_START: String = "stateDiagram-v2"
const ARROW: String = "-->"


func test_every_legal_transition_is_accepted() -> void:
	var checked: int = 0
	for from: RunFlow.State in RunFlow.TRANSITIONS:
		for to: RunFlow.State in RunFlow.TRANSITIONS[from]:
			var flow: RunFlow = RunFlow.new(from)
			assert_int(flow.move(to)).is_equal(RunFlow.Reason.OK)
			assert_int(flow.state()).is_equal(to)
			checked += 1
	assert_int(checked).is_greater(RunFlow.State.size())


func test_every_other_transition_is_refused_and_changes_nothing() -> void:
	var refused: int = 0
	for from: int in RunFlow.State.size():
		for to: int in RunFlow.State.size():
			if RunFlow.TRANSITIONS[from].has(to):
				continue
			var flow: RunFlow = RunFlow.new(from as RunFlow.State)
			assert_int(flow.move(to as RunFlow.State)).is_equal(RunFlow.Reason.ILLEGAL_TRANSITION)
			assert_int(flow.state()).is_equal(from)
			refused += 1
	assert_int(refused).is_greater(0)


func test_sample_of_illegal_moves_is_refused() -> void:
	var samples: Array[Array] = [
		[RunFlow.State.RUN_START, RunFlow.State.ROUND_PLAY],
		[RunFlow.State.SET_INTRO, RunFlow.State.SHOP],
		[RunFlow.State.ROUND_PLAY, RunFlow.State.BIDDING],
		[RunFlow.State.SHOP, RunFlow.State.BIDDING],
		[RunFlow.State.RUN_END, RunFlow.State.RUN_START],
		[RunFlow.State.REEDUCATION, RunFlow.State.ROUND_PLAY],
	]
	for sample: Array in samples:
		var flow: RunFlow = RunFlow.new(sample[0])
		assert_int(flow.move(sample[1])).is_equal(RunFlow.Reason.ILLEGAL_TRANSITION)


func test_every_state_has_an_entry_and_every_state_is_reachable() -> void:
	var reached: Dictionary[int, bool] = {RunFlow.State.RUN_START: true}
	for from: int in RunFlow.State.size():
		assert_bool(RunFlow.TRANSITIONS.has(from)).is_true()
		for to: int in RunFlow.TRANSITIONS[from]:
			reached[to] = true
	assert_int(reached.size()).is_equal(RunFlow.State.size())


func test_architecture_diagram_matches_the_table() -> void:
	var documented: Dictionary[String, bool] = {}
	for edge: String in _diagram_edges():
		documented[edge] = true
	var expected: Dictionary[String, bool] = {}
	for from: int in RunFlow.TRANSITIONS:
		for to: int in RunFlow.TRANSITIONS[from]:
			expected["%s %s" % [RunFlow.State.keys()[from], RunFlow.State.keys()[to]]] = true
	assert_array(documented.keys()).contains_exactly_in_any_order(expected.keys())


func _diagram_edges() -> Array[String]:
	var text: String = FileAccess.get_file_as_string(ARCHITECTURE)
	var edges: Array[String] = []
	var inside: bool = false
	for line: String in text.split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed == DIAGRAM_START:
			inside = true
		elif inside and trimmed.begins_with("```"):
			break
		elif inside and trimmed.contains(ARROW):
			var parts: PackedStringArray = trimmed.split(ARROW)
			var from: String = parts[0].strip_edges().trim_prefix("[*]")
			var to: String = parts[1].strip_edges()
			if not from.is_empty() and to != "[*]":
				edges.append("%s %s" % [from, to])
	return edges
