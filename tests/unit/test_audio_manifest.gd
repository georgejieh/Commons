extends GdUnitTestSuite
## Every sound under audio/ is logged with a license we may ship (P3C.8, commons-sfx):
## no row, no ship, and nothing NC, SA or Sampling+.

const ROOT: String = "res://audio"
const MANIFEST: String = "res://audio/sources/manifest.csv"
## Local working folders, gitignored and never shipped.
const SKIPPED: PackedStringArray = ["res://audio/sources/raw", "res://audio/preview"]
const AUDIO_EXTENSIONS: PackedStringArray = ["wav", "ogg", "mp3", "flac", "opus"]
## Whole-word license terms we never use.
const BANNED: PackedStringArray = ["NC", "SA", "Sampling+"]


func test_every_audio_file_is_in_the_manifest() -> void:
	var logged: Dictionary[String, String] = _manifest()
	var files: PackedStringArray = []
	_collect(ROOT, files)
	assert_int(files.size()).is_greater(0)
	for path: String in files:
		var key: String = path.trim_prefix("res://")
		assert_bool(logged.has(key)).override_failure_message("not in manifest: " + key).is_true()


func test_no_entry_uses_a_banned_license() -> void:
	var logged: Dictionary[String, String] = _manifest()
	assert_int(logged.size()).is_greater(0)
	for file: String in logged:
		var license: String = logged[file]
		assert_str(license).override_failure_message("no license: " + file).is_not_empty()
		for term: String in BANNED:
			(
				assert_bool(_has_term(license, term))
				. override_failure_message("%s uses %s" % [file, license])
				. is_false()
			)


func test_every_entry_names_a_file_that_exists() -> void:
	for file: String in _manifest():
		(
			assert_bool(FileAccess.file_exists("res://" + file))
			. override_failure_message(file)
			. is_true()
		)


func test_the_license_check_catches_nc_and_sa() -> void:
	assert_bool(_has_term("CC BY-NC 4.0", "NC")).is_true()
	assert_bool(_has_term("CC BY-SA 3.0", "SA")).is_true()
	assert_bool(_has_term("Sampling+ 1.0", "Sampling+")).is_true()
	assert_bool(_has_term("CC0", "NC")).is_false()
	assert_bool(_has_term("Original", "SA")).is_false()


## File path to license, from the manifest's header row.
func _manifest() -> Dictionary[String, String]:
	var rows: Dictionary[String, String] = {}
	var file: FileAccess = FileAccess.open(MANIFEST, FileAccess.READ)
	assert_object(file).override_failure_message("missing " + MANIFEST).is_not_null()
	if file == null:
		return rows
	var header: PackedStringArray = file.get_csv_line()
	var file_column: int = header.find("file")
	var license_column: int = header.find("license")
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() > maxi(file_column, license_column):
			rows[row[file_column]] = row[license_column]
	return rows


func _collect(dir_path: String, out: PackedStringArray) -> void:
	if SKIPPED.has(dir_path):
		return
	for sub: String in DirAccess.get_directories_at(dir_path):
		_collect(dir_path.path_join(sub), out)
	for name: String in DirAccess.get_files_at(dir_path):
		if AUDIO_EXTENSIONS.has(name.get_extension().to_lower()):
			out.append(dir_path.path_join(name))


## A license term as a whole word, so "SA" never matches inside another word.
func _has_term(license: String, term: String) -> bool:
	var escaped: String = term.replace("+", "\\+")
	var pattern: RegEx = RegEx.create_from_string("(^|[^A-Za-z])%s([^A-Za-z]|$)" % escaped)
	return pattern.search(license) != null
