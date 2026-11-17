class_name BaitLedger
extends RefCounted
## The bait (ADR 0022): a plain text file in the save folder, private_ledger.txt, with
## one line, the household's coupons. It is rewritten whenever the run save is written
## and removed with it. The save keeps, under its seal, the number written there and the
## number the ledger held just before, since a crash can fall between writing the save
## and the ledger. When the game next reads the folder, on continue and before each
## write, a ledger that parses to a whole number the save on disk does not hold is taken.
## A missing or unreadable ledger is nothing. So is any ledger before this run's first
## save is written, and any ledger beside a save that keeps no number, such as one read
## from its backup, which may be older than the ledger.

const FILE_NAME: String = "private_ledger.txt"
const TEMP_SUFFIX: String = ".tmp"
const NUMBER_KEY: String = "ledger"
const BEFORE_KEY: String = "ledger_before"
## No number: nothing written yet, or nothing found.
const NONE: int = -1

var _path: String
## The numbers the ledger may hold without an offence, as the save last said; and true
## until there is a save to hold the ledger to.
var _accepted: Array[int] = []
var _fresh: bool = true
var _pending: int = NONE


func _init(save_path: String) -> void:
	_path = path_for(save_path)


## The ledger beside a run save: private_ledger.txt beside the game's own run.json, and
## one named after any other save, so two saves in one folder never share a ledger.
static func path_for(save_path: String) -> String:
	var base: String = save_path.get_file().get_basename()
	var name: String = FILE_NAME if base == "run" else "%s_%s" % [base, FILE_NAME]
	return save_path.get_base_dir().path_join(name)


func path() -> String:
	return _path


## What the save about to be written keeps beside its data: the coupons the ledger will
## hold, and what it holds now.
func extras(coupons: int) -> Dictionary:
	return {NUMBER_KEY: coupons, BEFORE_KEY: _read()}


## Takes the numbers a loaded save kept. A save read from its backup, or one that kept
## none, holds the ledger to nothing until the next write.
func remember(loaded: SaveLoad) -> void:
	forget()
	if loaded == null or loaded.status != SaveLoad.Status.OK:
		return
	_accepted = numbers(loaded.extras)
	_fresh = _accepted.is_empty()


## Starts again, as for a new run: nothing to hold the ledger to until the first write.
func forget() -> void:
	_accepted.clear()
	_fresh = true
	_pending = NONE


## Reads the ledger. A number the last save named passes at once; any other is held to
## the save on disk, since another controller may have written both since, and a number
## that save does not hold either is kept until taken.
func peek(saves: SaveService) -> void:
	if _fresh:
		return
	var number: int = _read()
	if number == NONE or _accepted.has(number):
		return
	var held: Array[int] = numbers(saves.kept_extras())
	if held.is_empty():
		return
	_accepted = held
	if not held.has(number):
		_pending = number


## Holds the ledger to a number from now on, as once an offence was answered.
func accept(number: int) -> void:
	if not _accepted.has(number):
		_accepted.append(number)


## The number found that the save does not hold, or NONE, and forgets it.
func take() -> int:
	var found: int = _pending
	_pending = NONE
	return found


## The numbers the ledger is held to now, for naming an offence.
func accepted() -> Array[int]:
	return _accepted.duplicate()


## Writes the coupons into the ledger through a temporary file, so a crash never leaves
## half a number there, once the save that names them is written. before is what the
## save kept as the ledger's number before.
func write(coupons: int, before: int) -> void:
	_fresh = false
	_accepted.clear()
	_accepted.append(coupons)
	if before != NONE and before != coupons:
		_accepted.append(before)
	var temp: String = _path + TEMP_SUFFIX
	DirAccess.make_dir_recursive_absolute(_path.get_base_dir())
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return
	var stored: bool = file.store_string("%d\n" % coupons)
	file.close()
	if not stored:
		return
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(_path)
	DirAccess.rename_absolute(temp, _path)


## The whole numbers a save kept for the ledger.
static func numbers(extras: Dictionary) -> Array[int]:
	var found: Array[int] = []
	for key: String in [NUMBER_KEY, BEFORE_KEY]:
		var number: Variant = extras.get(key)
		if (number is int or number is float) and number >= 0 and number == floorf(number):
			found.append(int(number))
	return found


## The ledger's whole number, or NONE when it is missing or holds anything else.
func _read() -> int:
	if not FileAccess.file_exists(_path):
		return NONE
	var line: String = FileAccess.get_file_as_string(_path).strip_edges()
	if not line.is_valid_int():
		return NONE
	var number: int = line.to_int()
	return number if number >= 0 else NONE
