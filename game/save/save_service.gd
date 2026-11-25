class_name SaveService
extends RefCounted
## Writes and reads one save file as JSON with a schema version. A write goes to a
## temporary file first and is renamed into place, and the save it replaces is kept as
## a backup, so a crash at any point leaves one whole save. An older save is brought up
## to date one version at a time by the registered migrations, then checked by the
## validator, so a file that parses but lost its shape counts as damaged. Run saves and
## the profile save are separate files with their own services.
##
## From the version that seals (ADR 0022), every write carries a keyed checksum beside
## schema_version, over the data and any extras (SaveSeal), and is read back and checked
## before it replaces the save. A file from before that version has none and is not an
## offence. A file at or past it whose seal is missing or wrong still loads when its shape
## is valid; the load says so, and the service remembers it until it is taken.
##
## A save a newer build wrote is not damaged, only beyond this build (ADR 0037). It is
## never deleted or written over: before this build writes over its path, or deletes it,
## it is moved aside beside it, under NEWER_SUFFIX, and a write whose move fails is
## refused.

const SCHEMA_VERSION: int = 18
## The first run save schema that carries a seal.
const SEALED_FROM: int = 17
const RUN_PATH: String = "user://run.json"
const PROFILE_PATH: String = "user://profile.json"
const BACKUP_SUFFIX: String = ".bak"
const TEMP_SUFFIX: String = ".tmp"
const RESTORED_KEY: String = "save.restored_from_backup"
const UNREADABLE_KEY: String = "save.unreadable"
const NEWER_KEY: String = "save.newer_version"
## What a save from a newer version is renamed to, beside it: one a path, the latest.
const NEWER_SUFFIX: String = ".newer_version"
const SEAL_KEY: String = "seal"
const EXTRA_KEY: String = "extra"

## Files that belong to this save and go with it when it is deleted.
var companions: Array[String] = []

var _path: String
## From version to the function that turns a save of that version into the next.
var _migrations: Dictionary[int, Callable]
var _version: int
## Takes the migrated data and returns true when it is whole.
var _validator: Callable
var _sealed_from: int
## The seal its values make, for the last file a load found whose seal was missing or
## wrong, until taken; empty while none was.
var _tampered: String = ""


func _init(
	path: String = RUN_PATH,
	migrations: Dictionary[int, Callable] = {},
	version: int = SCHEMA_VERSION,
	validator: Callable = Callable(),
	sealed_from: int = SEALED_FROM
) -> void:
	_path = path
	_migrations = migrations
	_version = version
	_validator = validator
	_sealed_from = sealed_from


## A run save, checked as a RunRecord. The private ledger beside it goes with it.
static func for_run(path: String = RUN_PATH) -> SaveService:
	var migrations: Dictionary[int, Callable] = {
		1: RunRecord.migrate_from_1,
		2: RunRecord.migrate_from_2,
		3: RunRecord.migrate_from_3,
		4: RunRecord.migrate_from_4,
		5: RunRecord.migrate_from_5,
		6: RunRecord.migrate_from_6,
		7: RunRecord.migrate_from_7,
		8: RunRecord.migrate_from_8,
		9: RunRecord.migrate_from_9,
		10: RunRecord.migrate_from_10,
		11: RunRecord.migrate_from_11,
		12: RunRecord.migrate_from_12,
		13: RunRecord.migrate_from_13,
		# Names a saved run by its surnames as they read in the string table.
		14: RunRecord.migrate_from_14.bind(Surnames.texts()),
		15: RunRecord.migrate_from_15,
		16: RunRecord.migrate_from_16,
		17: RunRecord.migrate_from_17,
	}
	var service: SaveService = SaveService.new(path, migrations, SCHEMA_VERSION, RunRecord.is_valid)
	service.companions.append(BaitLedger.path_for(path))
	return service


func path() -> String:
	return _path


func backup_path() -> String:
	return _path + BACKUP_SUFFIX


## Full precision keeps every number the writer can keep; exact values travel as text.
## extras are kept beside the data, under the same seal. A failure is logged.
func save(data: Dictionary, extras: Dictionary = {}) -> Error:
	var result: Error = _replace(data, extras)
	if result != OK:
		GameLog.save_failed(_path, result)
	return result


func _replace(data: Dictionary, extras: Dictionary) -> Error:
	var temp: String = _path + TEMP_SUFFIX
	DirAccess.make_dir_recursive_absolute(_path.get_base_dir())
	var written: Error = _write(temp, data, extras)
	if written != OK:
		return written
	var main: Variant = _parse(_path)
	if _is_newer(main):
		var aside: Error = _set_aside(_path)
		if aside != OK:
			return aside
	elif _data_of(main) != null:
		# The backup is replaced only by a whole main file, never by a damaged one, which
		# leaves it the only good save.
		var kept: Error = _keep_if_newer(backup_path())
		if kept != OK:
			return kept
		if FileAccess.file_exists(backup_path()):
			DirAccess.remove_absolute(backup_path())
		kept = DirAccess.rename_absolute(_path, backup_path())
		if kept != OK:
			return kept
	elif FileAccess.file_exists(_path):
		DirAccess.remove_absolute(_path)
	return DirAccess.rename_absolute(temp, _path)


## The main file, or else its backup. A newer version's file is reported as that, and
## when the backup loads in its place the notice says so too.
func load_save() -> SaveLoad:
	var main: Variant = _parse(_path)
	var data: Variant = _data_of(main)
	if data != null:
		return _loaded(SaveLoad.Status.OK, data, main)
	var backup: Variant = _parse(backup_path())
	var newer: bool = _is_newer(main) or _is_newer(backup)
	if newer:
		GameLog.load_found_newer(_path)
	data = _data_of(backup)
	if data != null:
		GameLog.load_fell_back(_path)
		var key: String = NEWER_KEY if newer else RESTORED_KEY
		return _loaded(SaveLoad.Status.RESTORED_FROM_BACKUP, data, backup, key)
	if newer:
		return SaveLoad.new(SaveLoad.Status.NEWER_VERSION, {}, NEWER_KEY)
	if not FileAccess.file_exists(_path) and not FileAccess.file_exists(backup_path()):
		return SaveLoad.new(SaveLoad.Status.MISSING)
	GameLog.load_failed(_path)
	return SaveLoad.new(SaveLoad.Status.UNREADABLE, {}, UNREADABLE_KEY)


## When a load since the last call found a file whose seal was missing or wrong, the seal
## its values make, which names it; empty when none was. Forgets it.
func take_tampered() -> String:
	var found: String = _tampered
	_tampered = ""
	return found


## The extras the main file keeps beside its data, as it is on disk now, or none when it
## is missing or damaged.
func kept_extras() -> Dictionary:
	var parsed: Variant = _parse(_path)
	if parsed == null:
		return {}
	var save: Dictionary = parsed
	var extras: Variant = save.get(EXTRA_KEY, {})
	return extras if extras is Dictionary else {}


## Removes the save, its backup and its companions. A file from a newer version is moved
## aside instead, or left where it is when it cannot be.
func delete() -> void:
	for file_path: String in [_path, backup_path(), _path + TEMP_SUFFIX]:
		if _keep_if_newer(file_path) == OK and FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)
	for companion: String in companions:
		if FileAccess.file_exists(companion):
			DirAccess.remove_absolute(companion)


## Writes the file and reads it back. The seal is made over the values as JSON reads the
## very text written: the seal is the last key in sorted order, so it is spliced onto the
## end of that text and every other byte stays as it was sealed. A file that does not read
## back as the text written is a failed write, so the save it would replace is kept.
func _write(file_path: String, data: Dictionary, extras: Dictionary) -> Error:
	var wrapper: Dictionary = {"schema_version": _version, "data": data}
	if not extras.is_empty():
		wrapper[EXTRA_KEY] = extras
	var text: String = JSON.stringify(wrapper, "", true, true)
	var sealed: bool = _version >= _sealed_from
	if sealed:
		var parsed: Variant = JSON.parse_string(text)
		# Text JSON cannot read back would load as damaged anyway; the save it would
		# replace is kept.
		if not parsed is Dictionary:
			return ERR_INVALID_DATA
		var seal: String = _seal_of(parsed)
		text = text.left(text.length() - 1) + ',"%s":"%s"}' % [SEAL_KEY, seal]
	var stored: Error = _store(file_path, text)
	if stored != OK or not sealed:
		return stored
	# The same text reads as the same values, so it holds the seal it was given.
	return OK if FileAccess.get_file_as_string(file_path) == text else ERR_FILE_CORRUPT


func _store(file_path: String, text: String) -> Error:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var stored: bool = file.store_string(text)
	file.close()
	return OK if stored else ERR_FILE_CANT_WRITE


## What a load found: the data, the extras beside it, and whether the seal of the file
## it came from, save, failed.
func _loaded(
	status: SaveLoad.Status, data: Variant, save: Dictionary, key: String = ""
) -> SaveLoad:
	var result: SaveLoad = SaveLoad.new(status, data, key)
	var extras: Variant = save.get(EXTRA_KEY, {})
	result.extras = extras if extras is Dictionary else {}
	var version: int = int(save["schema_version"])
	if version >= _sealed_from and not _seal_holds(save):
		result.tampered = true
		result.seal = _seal_of(save)
		_tampered = result.seal
	return result


## True when a parsed save's seal is the one its values make.
func _seal_holds(save: Dictionary) -> bool:
	var seal: Variant = save.get(SEAL_KEY)
	return SaveSeal.is_shaped(seal) and seal == _seal_of(save)


func _seal_of(save: Dictionary) -> String:
	var extras: Variant = save.get(EXTRA_KEY, {})
	return SaveSeal.of(int(save["schema_version"]), save["data"], extras)


## The file as JSON when it parses to a save's shape, or null.
func _parse(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		return null
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(file_path)) != OK or not json.data is Dictionary:
		return null
	var save: Dictionary = json.data
	if not save.get("schema_version") is float or not save.get("data") is Dictionary:
		return null
	return save


## True for a parsed save that a newer build wrote.
func _is_newer(save: Variant) -> bool:
	if save == null:
		return false
	var parsed: Dictionary = save
	return int(parsed["schema_version"]) > _version


## Moves a file from a newer version aside, so nothing this build does can touch it, and
## logs the move. Any other file is left as it is.
func _keep_if_newer(file_path: String) -> Error:
	return _set_aside(file_path) if _is_newer(_parse(file_path)) else OK


## Renames the file to its aside name, over an older aside of the same path.
func _set_aside(file_path: String) -> Error:
	var aside: String = file_path + NEWER_SUFFIX
	var moved: Error = DirAccess.rename_absolute(file_path, aside)
	if moved == OK:
		GameLog.save_set_aside(file_path, aside)
	return moved


## The migrated data of a parsed save, or null when there is none or it is damaged or
## too new. An older save is migrated on a copy, so the parsed values its seal was made
## over stay as they were read.
func _data_of(save: Variant) -> Variant:
	if save == null:
		return null
	var parsed: Dictionary = save
	var version: int = int(parsed["schema_version"])
	var data: Dictionary = parsed["data"]
	if version < _version:
		data = data.duplicate(true)
	var migrated: Variant = _migrate(data, version)
	if migrated == null or (_validator.is_valid() and not _validator.call(migrated)):
		return null
	return migrated


## Brings data up to this version, or returns null when it is newer or a step is missing.
func _migrate(data: Dictionary, version: int) -> Variant:
	if version > _version:
		return null
	while version < _version:
		if not _migrations.has(version):
			return null
		data = _migrations[version].call(data)
		version += 1
	return data
