class_name PerfSaves
extends RefCounted
## The save rows of the budget, the reads one table event makes of a late run, and the
## memory of a loaded run. It plays a real full run
## through RunController for a few Sets, as a player would (the first Cadre it can afford
## at each store), with the run's autosaves going to the tool's folder in the sandbox,
## then measures the largest save the run wrote, and the time to write and to read it
## back. The player's own run save and profile are never touched, and the folder is
## removed after. Fewer repetitions than PerfLimits.MIN_SAVE_REPS, and the save and load
## times are reported as not measured.

## A run that is still going after this many player turns is cut off.
const MAX_TURNS: int = 200000
const MSEC: float = 1000.0
## Table events whose reads are timed, on the largest save resumed.
const EVENTS_TIMED: int = 2000

var _sets_wanted: int
var _reps: int
var _seed: int
## The folder the run saves into, with its trailing slash.
var _folder: String
var _largest: String = ""
var _largest_bytes: int = 0
var _cadres: int = 0
var _sets_played: int = 0
var _turns: int = 0
var _static_bytes: int = 0
var _resident_bytes: int = PerfMemory.NOT_AVAILABLE


func _init(first_seed: int, sets: int, reps: int, folder: String) -> void:
	_seed = first_seed
	_sets_wanted = sets
	_reps = reps
	_folder = folder


## The rows: the largest save's size, the time to save, the time to load, the engine's
## static memory with the run loaded, and the process's resident memory.
func rows() -> Array[PerfRow]:
	_clear()
	_play()
	var rows_made: Array[PerfRow] = []
	var big_path: String = _folder + "largest.json"
	if not ToolFiles.write(big_path, _largest):
		_clear()
		return _unmeasured("the largest save could not be written")
	var service: SaveService = SaveService.for_run(big_path)
	var loaded: SaveLoad = service.load_save()
	if loaded.status != SaveLoad.Status.OK:
		_clear()
		return _unmeasured("the largest save did not load back (status %d)" % loaded.status)
	var saves: PackedFloat64Array = _time_saves(service, loaded)
	var reads: PackedFloat64Array = _time_reads(service)
	var resumes: PackedFloat64Array = _time_resumes(service)
	var event_reads: PackedFloat64Array = _time_event_reads(service)
	_clear()
	rows_made.append(_size_row())
	rows_made.append(_time_row("Save time", saves, "write, read back and check, rename"))
	rows_made.append(_time_row("Load time", reads, "read, parse, migrate and check the file"))
	rows_made.append(_resume_row(resumes))
	rows_made.append(_reads_row(event_reads))
	rows_made.append_array(_memory_rows())
	return rows_made


func _play() -> void:
	var saves: SaveService = SaveService.for_run(_folder + "run.json")
	var profile: SaveService = Profile.service(_folder + "profile.json")
	var controller: RunController = RunController.new()
	controller.live_search = false
	controller.start(
		RunRequest.new(RunRequest.FULL, _seed, BalanceDriver.PARAMS.start_time), saves, profile
	)
	var script: ControllerScript = ControllerScript.new()
	while _sets_played < _sets_wanted and _turns < MAX_TURNS:
		while _act(controller, script):
			_turns += 1
			_note_size(saves)
		if not _between(controller):
			break
	_cadres = controller.state_copy().inventory.cadres.size()
	_static_bytes = PerfMemory.static_bytes()
	_resident_bytes = PerfMemory.resident_bytes()
	controller.free()


## The script's turn, but an honest claim on the Commons so the run is not ended early.
func _act(controller: RunController, script: ControllerScript) -> bool:
	if controller.awaiting() == RunController.AWAIT_NEED:
		return controller.declare_need(controller.figures.base_need()) == RunController.OK
	return script.act(controller)


## What the run waits on that is not a player turn. False when it waits on nothing the
## script answers, such as the run's end.
func _between(controller: RunController) -> bool:
	match controller.awaiting():
		RunController.AWAIT_SET_OVER:
			_sets_played += 1
			controller.finish_set()
		RunController.AWAIT_STORE:
			for slot: int in controller.store.store_stock().size():
				if controller.store.can_buy(slot):
					controller.buy(slot)
					break
			controller.leave_store()
		RunController.AWAIT_REEDUCATION:
			controller.leave_reeducation()
		_:
			return false
	return true


func _note_size(saves: SaveService) -> void:
	var file: FileAccess = FileAccess.open(saves.path(), FileAccess.READ)
	if file == null:
		return
	var bytes: int = file.get_length()
	if bytes > _largest_bytes:
		_largest_bytes = bytes
		_largest = file.get_as_text()


func _time_saves(service: SaveService, loaded: SaveLoad) -> PackedFloat64Array:
	var extras: Dictionary = service.kept_extras()
	var msec: PackedFloat64Array = PackedFloat64Array()
	for _rep: int in _reps:
		var started: int = Time.get_ticks_usec()
		service.save(loaded.data, extras)
		msec.append((Time.get_ticks_usec() - started) / MSEC)
	return msec


func _time_reads(service: SaveService) -> PackedFloat64Array:
	var msec: PackedFloat64Array = PackedFloat64Array()
	for _rep: int in _reps:
		var started: int = Time.get_ticks_usec()
		service.load_save()
		msec.append((Time.get_ticks_usec() - started) / MSEC)
	return msec


## The load a player waits for: the save read, checked and the run replayed to where it was.
func _time_resumes(service: SaveService) -> PackedFloat64Array:
	var msec: PackedFloat64Array = PackedFloat64Array()
	for _rep: int in _reps:
		var controller: RunController = RunController.new()
		controller.live_search = false
		var started: int = Time.get_ticks_usec()
		var resumed: bool = controller.continue_saved(service)
		msec.append((Time.get_ticks_usec() - started) / MSEC)
		if not resumed:
			msec.append(INF)
		controller.free()
	return msec


## What one table event costs the screens in reads of the run, on the largest save
## resumed: the reads an event that redraws the table's status, its small ledger and the
## room's dread makes of the run (TableScreen's _refresh_status and DreadLayers.refresh).
func _time_event_reads(service: SaveService) -> PackedFloat64Array:
	var usec: PackedFloat64Array = PackedFloat64Array()
	var controller: RunController = RunController.new()
	controller.live_search = false
	if controller.continue_saved(service):
		for _event: int in EVENTS_TIMED:
			var started: int = Time.get_ticks_usec()
			_event_reads(controller)
			usec.append(Time.get_ticks_usec() - started)
	controller.free()
	return usec


## The run as the table reads it for one such event: the status and ledger take one copy
## of the whole state, the dread another, and both read the target.
static func _event_reads(controller: RunController) -> void:
	for _reader: int in 2:
		var state: RunState = controller.state_copy()
		state.books.is_dark(RunCorrections.FAMINE)
	controller.figures.target()


func _size_row() -> PerfRow:
	var kib: float = _largest_bytes / 1024.0
	return PerfRow.judged(
		"Save file size",
		PerfLimits.save_size_budget(),
		"%.1f KB (%d bytes), the largest of the run's autosaves" % [kib, _largest_bytes],
		_largest_bytes < PerfLimits.SAVE_MAX_BYTES,
		"%d Sets played, %d player turns, %d Cadres held" % [_sets_played, _turns, _cadres],
		"a full run from seed %d, saved after every player turn" % _seed
	)


## Judged on the worst of the timed repetitions; shown with the median. Too few
## repetitions to judge a time, and it is not measured.
func _time_row(row_name: String, msec: PackedFloat64Array, note: String) -> PerfRow:
	if msec.size() < PerfLimits.MIN_SAVE_REPS:
		var why: String = (
			"%d repetitions, fewer than the %d a time is judged on"
			% [msec.size(), PerfLimits.MIN_SAVE_REPS]
		)
		return PerfRow.unmeasured(row_name, PerfLimits.save_time_budget(), why)
	var sorted: PackedFloat64Array = ToolStats.sorted_of(msec)
	var worst: float = sorted[-1]
	return PerfRow.judged(
		row_name,
		PerfLimits.save_time_budget(),
		"median %.2f ms, worst %.2f ms" % [ToolStats.nearest_rank(sorted, 50), worst],
		worst < PerfLimits.SAVE_TIME_MAX_MS,
		"%d repetitions of the largest save" % sorted.size(),
		note
	)


func _memory_rows() -> Array[PerfRow]:
	var budget: String = "under %s resident" % PerfMemory.megabytes(PerfLimits.MEMORY_MAX_BYTES)
	var static_text: String = "static memory %s" % PerfMemory.megabytes(_static_bytes)
	var static_row: PerfRow = PerfRow.new(
		"Static memory, run loaded (headless)",
		budget,
		static_text,
		(
			PerfRow.Verdict.MISS
			if _static_bytes >= PerfLimits.MEMORY_MAX_BYTES
			else PerfRow.Verdict.INFO
		),
		"once, after %d Sets" % _sets_played,
		"engine allocators only, not resident memory; reported, not judged unless it alone is over"
	)
	var resident_row: PerfRow = PerfRow.unmeasured(
		"Resident memory, run loaded (headless)", budget, "the operating system gave no figure"
	)
	if _resident_bytes != PerfMemory.NOT_AVAILABLE:
		resident_row = PerfRow.judged(
			"Resident memory, run loaded (headless)",
			budget,
			"resident %s" % PerfMemory.megabytes(_resident_bytes),
			_resident_bytes < PerfLimits.MEMORY_MAX_BYTES,
			"once, after %d Sets" % _sets_played,
			"process working set, headless with no window or GPU, so a floor for the game"
		)
	return [static_row, resident_row]


## Continue replays the run's record after the file is loaded, so it grows with the run.
## The budget's "load" is the file; this is reported and not judged.
func _resume_row(msec: PackedFloat64Array) -> PerfRow:
	var sorted: PackedFloat64Array = ToolStats.sorted_of(msec)
	return PerfRow.new(
		"Resume time",
		PerfLimits.resume_budget(),
		"median %.2f ms, worst %.2f ms" % [ToolStats.nearest_rank(sorted, 50), sorted[-1]],
		PerfRow.Verdict.INFO,
		"%d repetitions of the largest save" % sorted.size(),
		"Continue: the load, then the run replayed to where it was; grows with the run"
	)


func _reads_row(usec: PackedFloat64Array) -> PerfRow:
	if usec.is_empty():
		return PerfRow.unmeasured(
			"Run reads per table event", "none", "the largest save did not resume"
		)
	var sorted: PackedFloat64Array = ToolStats.sorted_of(usec)
	return PerfRow.new(
		"Run reads per table event",
		"none",
		(
			"median %.1f us, p99 %.1f us"
			% [ToolStats.nearest_rank(sorted, 50), ToolStats.nearest_rank(sorted, 99)]
		),
		PerfRow.Verdict.INFO,
		"%d events on the largest save, resumed" % sorted.size(),
		"what the table's status, small ledger and dread read of the run for one event"
	)


func _unmeasured(why: String) -> Array[PerfRow]:
	return [
		PerfRow.unmeasured("Save file size", PerfLimits.save_size_budget(), why),
		PerfRow.unmeasured("Save time", PerfLimits.save_time_budget(), why),
		PerfRow.unmeasured("Load time", PerfLimits.save_time_budget(), why),
		PerfRow.unmeasured("Resume time", PerfLimits.resume_budget(), why),
	]


func _clear() -> void:
	var directory: DirAccess = DirAccess.open(_folder)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		directory.remove(file_name)
	DirAccess.remove_absolute(_folder)
