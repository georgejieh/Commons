extends GdUnitTestSuite
## Every image under art/ is logged in art/sources/manifest.csv (P3C.2), which is also
## the store's AI-disclosure record, and every row points at a file that exists.

const ART: String = "res://art"
const MANIFEST: String = "res://art/sources/manifest.csv"
const IMAGE_TYPES: PackedStringArray = ["png", "jpg", "jpeg", "webp", "svg"]
const COLUMNS: PackedStringArray = ["file", "prompt", "model", "date", "edited"]


func test_every_image_is_in_the_manifest() -> void:
	var logged: Dictionary[String, bool] = _logged()
	var images: PackedStringArray = _images(ART)
	assert_int(images.size()).is_greater(0)
	for image: String in images:
		(
			assert_bool(logged.has(image))
			. override_failure_message("%s is missing from the manifest" % image)
			. is_true()
		)


func test_every_row_is_complete_and_points_at_a_file() -> void:
	for row: PackedStringArray in _rows():
		var path: String = "res://" + row[0]
		assert_bool(FileAccess.file_exists(path)).override_failure_message(path).is_true()
		assert_str(row[1]).is_not_empty()
		assert_str(row[2]).is_not_empty()
		assert_bool(row[4] in ["yes", "no"]).override_failure_message(row[0]).is_true()


func _logged() -> Dictionary[String, bool]:
	var logged: Dictionary[String, bool] = {}
	for row: PackedStringArray in _rows():
		logged[row[0]] = true
	return logged


func _rows() -> Array[PackedStringArray]:
	var file: FileAccess = FileAccess.open(MANIFEST, FileAccess.READ)
	var header: PackedStringArray = file.get_csv_line()
	assert_array(Array(header)).is_equal(Array(COLUMNS))
	var rows: Array[PackedStringArray] = []
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() == COLUMNS.size():
			rows.append(row)
	return rows


## Image paths under folder, relative to the project root, as the manifest writes them.
func _images(folder: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file_name: String in DirAccess.get_files_at(folder):
		if file_name.get_extension().to_lower() in IMAGE_TYPES:
			found.append(folder.path_join(file_name).trim_prefix("res://"))
	for child: String in DirAccess.get_directories_at(folder):
		found.append_array(_images(folder.path_join(child)))
	return found
