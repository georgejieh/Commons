extends GdUnitTestSessionHook
## Keeps TestFolder's roots from piling up: a test run removes its own root when it ends,
## and, when it starts, the root of every earlier run whose process is no longer alive. A
## root whose process still runs belongs to a run going on beside this one and is left.
## Registered in project.godot under gdunit4/hooks/session_hooks, so every gdUnit4 run,
## from tools/test.sh or the editor, uses it.


func _init() -> void:
	super("TestFolder", "Removes the test runs' save folders under %s." % TestFolder.ROOT)


func startup(_session: GdUnitTestSession) -> GdUnitResult:
	for pid: String in DirAccess.get_directories_at(TestFolder.ROOT):
		if pid.is_valid_int() and not _alive(int(pid)):
			GdUnitFileAccess.delete_directory(TestFolder.ROOT.path_join(pid))
	return GdUnitResult.success()


func shutdown(_session: GdUnitTestSession) -> GdUnitResult:
	GdUnitFileAccess.delete_directory(TestFolder.run_root())
	return GdUnitResult.success()


## Whether a process with this id runs now. The engine can only tell for a process it
## started itself, so the system's own list is asked.
static func _alive(pid: int) -> bool:
	if pid == OS.get_process_id():
		return true
	var output: Array = []
	if OS.get_name() == "Windows":
		OS.execute("tasklist", ["/FI", "PID eq %d" % pid, "/NH", "/FO", "CSV"], output)
		return str(output).contains('"%d"' % pid)
	return OS.execute("ps", ["-p", str(pid)], output) == 0
