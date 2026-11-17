class_name FileWatch
extends RefCounted
## The three ways the game notices a changed figure (ADR 0022), for one controller: the
## second book (SecondBook), the seal on the saves (SaveSeal, through SaveService) and
## the bait (BaitLedger). The controller calls it at the right moments and nothing else:
## started or resumed when it takes a loop over, check before each command it handles,
## sealed after, and before_write and written around each run save.
##
## Acting or only logging is decided in one place, acts(): a release build, in a full run
## with a profile, acts. An offence is then answered inside the fiction and never
## blocked: the true figures are put back, the books command takes what was found as
## official, and an entry goes into the family's file at once. Anything else logs one
## line starting LOG_LINE through report and changes nothing, and the book is sealed
## again to the figures as they are.

## The start of the one line a mismatch logs where the detectors do not act. The test
## script fails a run whose output holds it.
const LOG_LINE: String = "COMMONS FILE MISMATCH"
const PROFILE_FILE: String = "profile"
const RUN_FILE: String = "run"

## True in a release build. A test may set it for a controller it builds, with a profile
## in a temporary folder, to see the detectors act.
var release: bool = FileMode.release_build()
## Takes each logged line; push_error when not set. A test that trips a detector on
## purpose sets it, so the line never reaches the output.
var report: Callable = Callable()
## Entries written to the family's file this session, oldest first, for the notice.
var notices: Array[FileEntry] = []

var _book: SecondBook = SecondBook.new()
var _ledger: BaitLedger = null
var _saves: SaveService = null
var _profile: SaveService = null
## Lines logged this session, each once.
var _logged: Dictionary[String, bool] = {}


## The saves a run on this controller is about to use, before anything writes them. The
## ledger has nothing to be held to until the run's first save, or until a load.
func attach(saves: SaveService, profile: SaveService) -> void:
	_saves = saves
	_profile = profile
	_ledger = null if saves == null else BaitLedger.new(saves.path())


## A run began on this controller: the book takes its figures.
func started(loop: RunLoop) -> void:
	_book.seal(loop)
	_check_profile(loop)


## A loop resumed from a save, or handed over whole: the book takes its figures as the
## replay left them, the ledger the numbers the save kept, and whatever the load found
## is acted on now. Returns true when it changed the run, so the caller saves.
func resumed(loop: RunLoop, loaded: SaveLoad = null) -> bool:
	if _ledger != null:
		_ledger.remember(loaded)
	_book.seal(loop)
	if loaded != null and loaded.tampered:
		_seal_offence(loop, RUN_FILE, loaded.seal)
	return check(loop)


## Before the controller handles a command: compares the book, reads the ledger and asks
## the profile whether its seal held. Returns true when it changed the run. While a
## villager's play is searched (P5.0) no figure can be corrected, since the books command
## waits on the player, so the book and the ledger are left for the next check.
func check(loop: RunLoop) -> bool:
	var changed: bool = false
	if loop.awaiting() == RunLoop.Awaiting.VILLAGER_SEARCH:
		_check_profile(loop)
		return false
	if _book.holds(loop):
		var found: Dictionary = _book.differences(loop.state)
		if not found.is_empty():
			changed = _book_offence(loop, found)
	if _ledger != null:
		_ledger.peek(_saves)
		var number: int = _ledger.take()
		if number != BaitLedger.NONE:
			changed = _bait_offence(loop, number) or changed
	_check_profile(loop)
	return changed


## After the controller handled a command, or anything else that moved the run.
func sealed(loop: RunLoop) -> void:
	_book.seal(loop)


## The run is let go.
func dropped() -> void:
	_book.clear()


## Before a run save is written: the ledger is read, and a number the save does not hold
## is acted on at the next check. Returns what the save keeps beside its data.
func before_write(coupons: int) -> Dictionary:
	if _ledger == null:
		return {}
	_ledger.peek(_saves)
	return _ledger.extras(coupons)


## After a run save was written whole, with extras: the ledger takes the coupons.
func written(extras: Dictionary) -> void:
	if _ledger == null or extras.is_empty():
		return
	var before: Variant = extras[BaitLedger.BEFORE_KEY]
	_ledger.write(int(extras[BaitLedger.NUMBER_KEY]), int(before))


## The one decision: a release build, in a full run with a profile to write.
func acts(loop: RunLoop) -> bool:
	return release and _profile != null and loop.state.identity.is_full()


func _check_profile(loop: RunLoop) -> void:
	if _profile == null:
		return
	var seal: String = _profile.take_tampered()
	if not seal.is_empty():
		_seal_offence(loop, PROFILE_FILE, seal)


## The numbers changed while nobody acted: the true ones go back, and what was found is
## reported through the books command, before the player's command goes on.
func _book_offence(loop: RunLoop, found: Dictionary) -> bool:
	if not acts(loop):
		_log(FileEntry.BOOK, found)
		return false
	_book.restore(loop.state)
	var key: String = "%d:%s" % [loop.record.commands.size(), JSON.stringify(found, "", true)]
	_file(loop, FileEntry.BOOK, found, key)
	loop.player_books(found)
	return true


## The ledger holds a number the save does not: the household's coupons are reported as
## that number.
func _bait_offence(loop: RunLoop, number: int) -> bool:
	var found: Dictionary = {RunCorrections.COUPONS: number}
	# The offence is named by the number found and the number the save holds, the same in
	# this session and on a reload of that save.
	var held: Array[int] = _ledger.accepted()
	var saved: int = BaitLedger.NONE if held.is_empty() else held[0]
	# Answered once: the ledger is not held against this number again before it is
	# rewritten.
	_ledger.accept(number)
	if not acts(loop):
		_log(FileEntry.BAIT, found)
		return false
	if number == loop.state.coupons:
		return false
	_file(loop, FileEntry.BAIT, found, "%d:%d" % [number, saved])
	loop.player_books(found)
	return true


## A save's seal was missing or wrong: an entry and a notice, with nothing to correct.
func _seal_offence(loop: RunLoop, which: String, seal: String) -> void:
	if not acts(loop):
		_log(FileEntry.SEAL, {which: seal})
		return
	if not _file(loop, FileEntry.SEAL, {}, "%s:%s" % [which, seal]):
		return
	var notice: RunEvent = RunEvent.new(
		RunEvent.Type.BOOKS_CORRECTED, RunLoop.PLAYER, loop.state.books.corrections
	)
	notice.correction = BooksCorrection.new()
	loop.set_log.add(notice)


## Writes the entry at once, keyed so the same offence is filed once. Returns true when
## it was new.
func _file(loop: RunLoop, detector: String, found: Dictionary, detail: String) -> bool:
	var state: RunState = loop.state
	var entry: FileEntry = FileEntry.new()
	entry.detector = detector
	entry.run_id = state.identity.id
	entry.generation = state.identity.generation
	entry.year = state.year
	entry.quota = ProfileCommits.quota_number(state)
	var kept: Dictionary = RunCorrections.clamped(
		found, RunLoop.DEFAULT_PARAMS, RunLoop.DEFAULT_RESENTMENT, RunBooks.DEFAULT_PARAMS
	)
	for figure: String in kept:
		var value: Variant = kept[figure]
		entry.figures[figure] = (
			RunState.float_from_text(value) if value is String else float(value)
		)
	entry.key = "%s:%s:%s" % [detector, state.identity.id, detail]
	if not ProfileFile.add(_profile, entry):
		return false
	notices.append(entry)
	return true


## Logs the line once for each offence, so a file left broken is not named every command.
func _log(detector: String, found: Dictionary) -> void:
	var line: String = "%s: %s %s" % [LOG_LINE, detector, JSON.stringify(found, "", true)]
	if _logged.has(line):
		return
	_logged[line] = true
	if report.is_valid():
		report.call(line)
	else:
		push_error(line)
