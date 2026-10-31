extends GdUnitTestSuite
## The core layer rules hold, and the checker catches each kind of violation.

const FIXTURES: String = "res://tests/fixtures/layers/"


func test_core_follows_layer_rules() -> void:
	var problems: PackedStringArray = LayerCheck.scan("res://core", LayerCheck.declared_autoloads())
	assert_array(problems).is_empty()


func test_clean_script_passes() -> void:
	assert_array(LayerCheck.scan(FIXTURES + "good", [])).is_empty()


func test_path_outside_core_fails() -> void:
	assert_array(LayerCheck.scan(FIXTURES + "bad_path", [])).has_size(1)


func test_node_subclass_fails() -> void:
	assert_array(LayerCheck.scan(FIXTURES + "bad_node", [])).has_size(1)


func test_autoload_access_fails() -> void:
	var problems: PackedStringArray = LayerCheck.scan(
		FIXTURES + "bad_autoload", ["FixtureAutoload"]
	)
	assert_array(problems).has_size(1)
