class_name ToolFiles
extends RefCounted
## The file work every tool shares: writing a report, saving a picture and listing the
## files under a folder. A write says whether it happened, and a tool that could not write
## its report exits 1 (docs/CODE_STANDARD.md). Development only; tools/ never ships.


## Writes text to path, making its folder first. False, said on stderr, when it could not.
static func write(path: String, text: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null or not file.store_string(text):
		printerr("Can't write %s" % path)
		return false
	return true


## Saves image as a PNG at path, res:// or user:// or absolute, making its folder first.
## False, said on stderr, when it could not.
static func save_png(image: Image, path: String) -> bool:
	var target: String = ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	var error: Error = image.save_png(target)
	if error != OK:
		printerr("Can't save %s: %s" % [path, error_string(error)])
		return false
	return true


## Every file under root and its folders, a folder's own files before its subfolders',
## with one of extensions (every file when it is empty), skipping the folders in skipped.
static func under(
	root: String, extensions: PackedStringArray = [], skipped: PackedStringArray = []
) -> PackedStringArray:
	var files: PackedStringArray = []
	if skipped.has(root):
		return files
	for file: String in DirAccess.get_files_at(root):
		if extensions.is_empty() or extensions.has(file.get_extension()):
			files.append(root.path_join(file))
	for directory: String in DirAccess.get_directories_at(root):
		files.append_array(under(root.path_join(directory), extensions, skipped))
	return files
