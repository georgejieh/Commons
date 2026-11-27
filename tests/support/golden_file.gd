class_name GoldenFile
extends RefCounted
## A committed file a test compares its text with. Set UPDATE_GOLDEN=1 to rewrite it from
## the test's text after an intended change.


## The golden file's text with its line ends as \n (git may check it out with \r\n),
## written from made first when UPDATE_GOLDEN is 1.
static func text(path: String, made: String) -> String:
	if OS.get_environment("UPDATE_GOLDEN") == "1":
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null or not file.store_string(made):
			push_error("The golden file %s could not be written." % path)
		if file != null:
			file.close()
	return FileAccess.get_file_as_string(path).replace("\r", "")
