extends GdUnitTestSuite
## The core layer rules hold, and the checker catches every known form of violation.

const FIXTURES: String = "res://tests/fixtures/layers/"


func test_core_follows_layer_rules() -> void:
	assert_array(LayerCheck.scan("res://core")).is_empty()


func test_clean_folder_passes_including_nested_scripts_and_comments() -> void:
	assert_array(LayerCheck.scan(FIXTURES + "good")).is_empty()


func test_missing_root_fails() -> void:
	_assert_flagged("does_not_exist", "folder not found")


func test_path_outside_core_fails() -> void:
	_assert_flagged("bad_path", "outside core and data")


func test_normalized_path_escape_fails() -> void:
	_assert_flagged("bad_normalized", "outside core and data")


func test_path_after_hash_in_string_fails() -> void:
	_assert_flagged("bad_hash_string", "outside core and data")


func test_relative_path_fails() -> void:
	_assert_flagged("bad_relative", "relative path")


func test_uid_reference_fails() -> void:
	_assert_flagged("bad_uid", "uid reference")


func test_runtime_load_fails() -> void:
	_assert_flagged("bad_load", "forbidden name: load")


func test_node_subclass_fails() -> void:
	_assert_flagged("bad_node", "Node subclass")


func test_one_line_class_name_node_fails() -> void:
	_assert_flagged("bad_one_line", "Node subclass")


func test_quoted_base_node_fails() -> void:
	_assert_flagged("bad_quoted_base", "Node subclass")


func test_inner_node_class_fails() -> void:
	_assert_flagged("bad_inner", "Node subclass")


func test_global_class_outside_core_fails() -> void:
	_assert_flagged("bad_global_class", "forbidden name: LayerCheck")


func test_autoload_access_fails() -> void:
	_assert_flagged("bad_autoload", "forbidden name: _mcp_game_helper")


func test_scene_tree_access_fails() -> void:
	_assert_flagged("bad_tree", "forbidden name: get_main_loop")


func test_engine_singleton_fails() -> void:
	_assert_flagged("bad_singleton", "forbidden name: OS")


func test_scene_in_core_fails() -> void:
	_assert_flagged("bad_scene", "scene in core")


func _assert_flagged(folder: String, reason: String) -> void:
	var report: String = "\n".join(LayerCheck.scan(FIXTURES + folder))
	assert_str(report).contains(reason)
