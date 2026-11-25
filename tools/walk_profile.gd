extends RefCounted
## Where a playtest tool keeps its saves under user://. Two tools running at once must
## not share a folder, or each overwrites the other's run save and both fail: --profile
## NAME gives a run its own (user://playtest_NAME/). Without it the folder is the tool's
## usual one. Loaded at run time by path, like the other tools.
## Development only; tools/ never ships.

const FLAG: String = "--profile"


## The folder for a tool whose usual folder is user://base/, with its trailing slash.
static func folder(base: String, args: PackedStringArray) -> String:
	var at: int = args.find(FLAG)
	if at < 0 or at + 1 >= args.size():
		return "user://%s/" % base
	return "user://%s_%s/" % [base, args[at + 1].validate_filename()]
