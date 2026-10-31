extends GdUnitTestSuite
## Definitions, hook order and derived caches.

const FIXTURES: String = "res://tests/fixtures/modifiers/"
const DATA: String = "res://data/"
const STRINGS: String = "res://data/strings/strings.csv"
const QUERIES: int = 1000


## Adds one Grain each time it runs, and carries a label.
class Recorder:
	extends ModifierEffect
	var label: String

	func _init(name: String) -> void:
		label = name

	func play_scored(context: PlayContext) -> void:
		context.add_grain += 1.0


func _string_keys() -> Dictionary[String, bool]:
	var keys: Dictionary[String, bool] = {}
	var file: FileAccess = FileAccess.open(STRINGS, FileAccess.READ)
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if not row[0].is_empty():
			keys[row[0]] = true
	file.close()
	return keys


func _resources_under(folder: String) -> PackedStringArray:
	var paths: PackedStringArray = []
	for file: String in ResourceLoader.list_directory(folder):
		if file.ends_with("/"):
			paths.append_array(_resources_under(folder + file))
		elif file.ends_with(".tres"):
			paths.append(folder + file)
	return paths


func _def(kind: ModifierDef.Kind) -> ModifierDef:
	var definition: ModifierDef = ModifierDef.new()
	definition.kind = kind
	return definition


func _load_def(name: String) -> ModifierDef:
	return ResourceLoader.load(DATA + "modifiers/" + name + ".tres")


func test_every_definition_in_data_is_valid() -> void:
	var keys: Dictionary[String, bool] = _string_keys()
	var checked: int = 0
	for path: String in _resources_under(DATA):
		var definition: ModifierDef = ResourceLoader.load(path) as ModifierDef
		if definition != null:
			checked += 1
			assert_array(Array(ModifierValidator.validate(definition, keys))).is_empty()
	assert_bool(checked >= 4).is_true()


func test_the_validator_catches_each_kind_of_bad_definition() -> void:
	var keys: Dictionary[String, bool] = _string_keys()
	var cases: Dictionary[String, String] = {
		"bad_hook.tres": "unknown hook",
		"bad_parameter.tres": "missing parameter",
		"bad_effect.tres": "no effect script",
		"bad_string.tres": "missing string key",
	}
	for file: String in cases:
		var definition: ModifierDef = ResourceLoader.load(FIXTURES + file)
		var problems: String = "\n".join(ModifierValidator.validate(definition, keys))
		assert_str(problems).contains(cases[file])


func test_the_hook_list_is_complete_and_each_hook_is_a_method() -> void:
	assert_int(Hooks.ALL.size()).is_equal(11)
	var effect: ModifierEffect = ModifierEffect.new()
	for hook: String in Hooks.ALL:
		assert_bool(effect.has_method(hook)).is_true()


func test_architecture_lists_every_hook() -> void:
	var text: String = FileAccess.get_file_as_string("res://docs/ARCHITECTURE.md")
	for hook: String in Hooks.ALL:
		assert_str(text).contains("`%s`" % hook)


func test_hooks_run_cadres_then_debuffs_then_the_boss() -> void:
	var stack: ModifierStack = ModifierStack.new()
	var effects: Array[Array] = [
		["boss", ModifierDef.Kind.BOSS_TWIST],
		["debuff one", ModifierDef.Kind.DEBUFF],
		["cadre left", ModifierDef.Kind.CADRE],
		["debuff two", ModifierDef.Kind.DEBUFF],
		["cadre right", ModifierDef.Kind.CADRE],
	]
	for row: Array in effects:
		stack.add_entry(ActiveModifier.new(_def(row[1]), Recorder.new(row[0])))
	var context: PlayContext = PlayContext.new(0, false, Pattern.pass_play(), 0.0, 0.0, 1.0)
	stack.run_play_scored(context)
	assert_float(context.add_grain).is_equal(5.0)
	assert_array(_labels(stack)).is_equal(
		["cadre left", "cadre right", "debuff one", "debuff two", "boss"]
	)


func _labels(stack: ModifierStack) -> Array[String]:
	var labels: Array[String] = []
	for entry: ActiveModifier in stack.ordered_entries():
		var recorder: Recorder = entry.effect
		labels.append(recorder.label)
	return labels


func test_disabled_modifiers_do_not_run() -> void:
	var stack: ModifierStack = ModifierStack.new()
	var entry: ActiveModifier = ActiveModifier.new(_def(ModifierDef.Kind.CADRE), Recorder.new("x"))
	stack.add_entry(entry)
	var context: PlayContext = PlayContext.new(0, false, Pattern.pass_play(), 0.0, 0.0, 1.0)
	stack.run_play_scored(context)
	assert_float(context.add_grain).is_equal(1.0)
	stack.set_enabled(entry, false)
	stack.run_play_scored(context)
	assert_float(context.add_grain).is_equal(1.0)


func test_queries_never_rebuild() -> void:
	var stack: ModifierStack = ModifierStack.new()
	stack.add(_load_def("promotion_of_the_masses"), 0)
	var table: SeatRules = SeatRules.new(stack)
	table.start_round(0)
	var before: int = table.rebuilds
	var counts: PackedByteArray = RankText.counts("3334")
	for index: int in QUERIES:
		var seat: int = index % Seats.COUNT
		Classifier.classify(counts, table.rules_for(seat), table.map_for(seat))
	assert_int(table.rebuilds).is_equal(before)


func test_each_change_marks_the_cache_for_one_rebuild() -> void:
	var stack: ModifierStack = ModifierStack.new()
	var table: SeatRules = SeatRules.new(stack)
	var before: int = table.rebuilds
	var entry: ActiveModifier = stack.add(_load_def("promotion_of_the_masses"), 0)
	table.refresh()
	assert_int(table.rebuilds).is_equal(before + 1)
	assert_int(table.map_for(0)[Ranks.THREE]).is_equal(Ranks.TWO)
	table.refresh()
	assert_int(table.rebuilds).is_equal(before + 1)
	stack.set_enabled(entry, false)
	table.refresh()
	assert_int(table.rebuilds).is_equal(before + 2)
	assert_int(table.map_for(0)[Ranks.THREE]).is_equal(Ranks.THREE)
	stack.set_enabled(entry, true)
	stack.remove(entry)
	table.refresh()
	assert_int(table.map_for(0)[Ranks.THREE]).is_equal(Ranks.THREE)
	var after_remove: int = table.rebuilds
	table.start_round(1)
	assert_int(table.rebuilds).is_equal(after_remove + 1)
