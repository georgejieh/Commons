class_name FileWatchKit
extends RefCounted
## What the file's detector suites share (ADR 0022): a run save and a profile in the
## suite's own folder, controllers whose detectors act or only log as asked and whose
## logged lines are taken here so none reaches the output, and one honest command of
## whatever the run waits on.

const SEED: int = 7207
const START_TIME: int = 1_763_300_000
## A walk stops past this many commands, so a test that goes wrong ends by itself.
const MAX_COMMANDS: int = 600
## Besides the first time each stopping point is met, a walk continues from the save
## every this many commands.
const CONTINUE_EVERY: int = 17
## What a refused or impossible answer reads as.
const REFUSED: int = -1

var saves: SaveService
var profile: SaveService
## Every line the detectors logged.
var lines: PackedStringArray = []
var driver: ControllerScript = ControllerScript.new()


func _init(dir: String) -> void:
	saves = SaveService.for_run(dir + "run.json")
	profile = Profile.service(dir + "profile.json")


func reset() -> void:
	saves.delete()
	profile.delete()
	lines.clear()


## A controller that searches with no limit, so a seed plays the same, whose detectors
## act when acting is true. The caller frees it.
func controller(acting: bool) -> RunController:
	var made: RunController = RunController.new()
	made.live_search = false
	made.file_watch.release = acting
	made.file_watch.report = func(line: String) -> void: lines.append(line)
	return made


static func full(seed_value: int = SEED) -> RunRequest:
	return RunRequest.new(RunRequest.FULL, seed_value, START_TIME)


static func loop_of(run: RunController) -> RunLoop:
	return run.run_loop()


## One command of whatever the run waits on, honestly. False at the run's end, or when
## the command was refused.
func one_command(run: RunController) -> bool:
	var awaiting: int = run.awaiting()
	if awaiting == RunController.AWAIT_RUN_OVER:
		return false
	if awaiting == RunController.AWAIT_STORE:
		return _shop(run) == RunController.OK
	return _answer(run, awaiting) == RunController.OK


func _answer(run: RunController, awaiting: int) -> int:
	match awaiting:
		RunController.AWAIT_NEED:
			return run.declare_need(run.base_need())
		RunController.AWAIT_SWAP:
			var none: Array[int] = []
			return run.swap(none, none)
		RunController.AWAIT_SET_OVER:
			return run.finish_set()
		RunController.AWAIT_REEDUCATION:
			return run.leave_reeducation()
	return RunController.OK if driver.act(run) else REFUSED


## Buys the first Cadre the coupons allow, or leaves.
func _shop(run: RunController) -> int:
	for slot: int in run.store_stock().size():
		if run.can_buy(slot):
			return run.buy(slot)
	return run.leave_store()


func entries() -> Array[FileEntry]:
	return Profile.read(profile).file


## The BOOKS_CORRECTED events in the Quota's log.
static func corrections(run: RunController) -> int:
	var count: int = 0
	for event: RunEvent in run.set_events():
		if event.type == RunEvent.Type.BOOKS_CORRECTED:
			count += 1
	return count


static func has_books_command(run: RunController) -> bool:
	for command: Dictionary in loop_of(run).record.commands:
		if command["type"] == "books":
			return true
	return false


func ledger_path() -> String:
	return BaitLedger.path_for(saves.path())


static func write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Rewrites a save file with change applied to its parsed JSON, seal and all.
static func edit(path: String, change: Callable) -> void:
	var save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	change.call(save)
	write_text(path, JSON.stringify(save, "", true, true))


static func state_text(run: RunController) -> String:
	return JSON.stringify(run.state_copy().to_dict(), "", true, true)


static func entry(key: String) -> FileEntry:
	var made: FileEntry = FileEntry.new()
	made.detector = FileEntry.BOOK
	made.run_id = "1-2"
	made.figures["coupons"] = 50.0
	made.key = key
	return made
