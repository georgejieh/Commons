class_name TestFolder
extends RefCounted
## Where a suite keeps the files it writes: a folder named for the suite under a root that
## is this test run's own, user://tests/<process id>/. user:// is one folder for every
## checkout of the project on a machine, so two runs at once (two worktrees, or a
## developer and a tool) would otherwise write the same files. TestFolderHook removes the
## root when the run ends, and the roots of runs no longer alive when one starts.

const ROOT: String = "user://tests"


## The folder for suite, ending in a slash, made if it is missing.
static func of(suite: String) -> String:
	var folder: String = run_root().path_join(suite) + "/"
	DirAccess.make_dir_recursive_absolute(folder)
	return folder


## This run's root, which holds every suite's folder.
static func run_root() -> String:
	return ROOT.path_join(str(OS.get_process_id()))
