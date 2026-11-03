class_name SaveService
extends RefCounted
## Writes and reads one save file as JSON with a schema version. A write goes to a
## temporary file first and is renamed into place, and the save it replaces is kept as
## a backup, so a crash at any point leaves one whole save. An older save is brought up
## to date one version at a time by the registered migrations. Run saves and the
## profile save are separate files with their own services.

const SCHEMA_VERSION: int = 1
const RUN_PATH: String = "user://run.json"
## Reserved for P4.14.
const PROFILE_PATH: String = "user://profile.json"
const BACKUP_SUFFIX: String = ".bak"
const TEMP_SUFFIX: String = ".tmp"
const RESTORED_KEY: String = "save.restored_from_backup"
const UNREADABLE_KEY: String = "save.unreadable"

var _path: String
## From version to the function that turns a save of that version into the next.
var _migrations: Dictionary[int, Callable]
var _version: int


func _init(
	path: String = RUN_PATH,
	migrations: Dictionary[int, Callable] = {},
	version: int = SCHEMA_VERSION
) -> void:
	_path = path
	_migrations = migrations
	_version = version


func path() -> String:
	return _path


func backup_path() -> String:
	return _path + BACKUP_SUFFIX


## Full precision keeps every number the writer can keep; exact values travel as text.
func save(data: Dictionary) -> Error:
	var text: String = JSON.stringify({"schema_version": _version, "data": data}, "", true, true)
	var temp: String = _path + TEMP_SUFFIX
	DirAccess.make_dir_recursive_absolute(_path.get_base_dir())
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var stored: bool = file.store_string(text)
	file.close()
	if not stored:
		return ERR_FILE_CANT_WRITE
	if FileAccess.file_exists(_path):
		if FileAccess.file_exists(backup_path()):
			DirAccess.remove_absolute(backup_path())
		var kept: Error = DirAccess.rename_absolute(_path, backup_path())
		if kept != OK:
			return kept
	return DirAccess.rename_absolute(temp, _path)


func load_save() -> SaveLoad:
	var main: Variant = _read(_path)
	if main != null:
		return SaveLoad.new(SaveLoad.Status.OK, main)
	var backup: Variant = _read(backup_path())
	if backup != null:
		return SaveLoad.new(SaveLoad.Status.RESTORED_FROM_BACKUP, backup, RESTORED_KEY)
	if not FileAccess.file_exists(_path) and not FileAccess.file_exists(backup_path()):
		return SaveLoad.new(SaveLoad.Status.MISSING)
	return SaveLoad.new(SaveLoad.Status.UNREADABLE, {}, UNREADABLE_KEY)


func delete() -> void:
	for file_path: String in [_path, backup_path(), _path + TEMP_SUFFIX]:
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)


## Returns the migrated data, or null when the file is missing, damaged or too new.
func _read(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		return null
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(file_path)) != OK or not json.data is Dictionary:
		return null
	var save: Dictionary = json.data
	if not save.get("schema_version") is float or not save.get("data") is Dictionary:
		return null
	var version: int = int(save["schema_version"])
	var data: Dictionary = save["data"]
	if version > _version:
		return null
	while version < _version:
		if not _migrations.has(version):
			return null
		data = _migrations[version].call(data)
		version += 1
	return data
