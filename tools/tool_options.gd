class_name ToolOptions
extends RefCounted
## The command line of a tool run with --script, read one way. Each --name takes the word
## after it as its value unless that word is itself a --flag, so a flag can stand alone.
## A typed read checks what it reads and keeps the first fault; failed() prints that fault
## with the tool's usage line, and the tool then exits 2. A path read here is under the
## project folder when it is relative and used as given when it is absolute (res://,
## user:// or the file system's own), for reports and pictures alike.
## Development only; tools/ never ships.

## Wide enough for any count or seed a tool takes, as the bound an unbounded read checks.
const LIMIT: int = 1 << 62

var _values: Dictionary[String, String] = {}
var _usage: String
var _problem: String = ""


## Reads args, which are the tool's own arguments after "--" unless a test passes others.
func _init(usage: String, args: PackedStringArray = OS.get_cmdline_user_args()) -> void:
	_usage = usage
	var at: int = 0
	while at < args.size():
		var name: String = args[at].trim_prefix("--")
		var has_value: bool = at + 1 < args.size() and not args[at + 1].begins_with("--")
		_values[name] = args[at + 1] if has_value else ""
		at += 2 if has_value else 1


## A path as a tool reads it: relative under the project folder, absolute as given.
static func resolve(given: String) -> String:
	return given if given.is_absolute_path() else "res://" + given


## True when --name was given, with or without a value.
func has(name: String) -> bool:
	return _values.has(name)


## The value given for --name, or fallback when it was not given.
func text(name: String, fallback: String = "") -> String:
	return _values.get(name, fallback)


## The whole number given for --name, from lowest to highest, or fallback when it was not
## given. Anything else is a fault, and fallback is returned.
func integer(name: String, fallback: int, lowest: int = -LIMIT, highest: int = LIMIT) -> int:
	if not has(name):
		return fallback
	var value: String = text(name)
	if not value.is_valid_int():
		refuse("--%s takes a whole number, not '%s'." % [name, value])
		return fallback
	var read: int = value.to_int()
	if read < lowest or read > highest:
		refuse(
			_bounds(
				name,
				"" if lowest == -LIMIT else str(lowest),
				"" if highest == LIMIT else str(highest)
			)
		)
		return fallback
	return read


## The number given for --name, from lowest to highest, or fallback when it was not given.
func number(name: String, fallback: float, lowest: float = -INF, highest: float = INF) -> float:
	if not has(name):
		return fallback
	var value: String = text(name)
	if not value.is_valid_float():
		refuse("--%s takes a number, not '%s'." % [name, value])
		return fallback
	var read: float = value.to_float()
	if read < lowest or read > highest:
		refuse(
			_bounds(
				name, "" if is_inf(lowest) else str(lowest), "" if is_inf(highest) else str(highest)
			)
		)
		return fallback
	return read


## The path given for --name, or fallback, by the rule in this file's comment.
func path(name: String, fallback: String) -> String:
	return resolve(text(name, fallback))


## Keeps a fault the tool found in its options itself; the first one kept is reported.
func refuse(problem: String) -> void:
	if _problem.is_empty():
		_problem = problem


## True when any read found a fault: prints it and the usage line, for the tool to exit 2.
func failed() -> bool:
	if _problem.is_empty():
		return false
	printerr(_problem)
	printerr("Usage: %s" % _usage)
	return true


## The fault for a value out of bounds; an empty bound is none.
func _bounds(name: String, lowest: String, highest: String) -> String:
	if lowest.is_empty():
		return "--%s takes at most %s." % [name, highest]
	if highest.is_empty():
		return "--%s takes at least %s." % [name, lowest]
	return "--%s takes from %s to %s." % [name, lowest, highest]
