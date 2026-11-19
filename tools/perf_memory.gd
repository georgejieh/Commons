class_name PerfMemory
extends RefCounted
## What this process holds in memory, as far as Godot and the operating system say.
## Godot 4.7 has no call for the resident set: OS.get_memory_info() reports the machine's
## RAM, and the Performance monitors report the engine's own static, texture and video
## memory. The resident set is therefore read from the operating system's own tool for
## this process (tasklist on Windows, ps elsewhere), and is -1 where that fails.

const KIB: int = 1024
const NOT_AVAILABLE: int = -1


## Bytes the engine's allocators hold. Not the resident set: it leaves out the executable,
## the graphics driver, thread stacks and anything the engine does not allocate itself.
static func static_bytes() -> int:
	return OS.get_static_memory_usage()


## The process's resident set (the working set on Windows) in bytes, or NOT_AVAILABLE.
static func resident_bytes() -> int:
	var pid: int = OS.get_process_id()
	var output: Array = []
	var code: int = -1
	if OS.get_name() == "Windows":
		var args: PackedStringArray = ["/FI", "PID eq %d" % pid, "/FO", "CSV", "/NH"]
		code = OS.execute("tasklist", args, output, false)
	else:
		code = OS.execute("ps", ["-o", "rss=", "-p", str(pid)], output, false)
	if code != 0 or output.is_empty():
		return NOT_AVAILABLE
	var kib: int = _kib_in(String(output[0]), OS.get_name() == "Windows")
	return kib * KIB if kib != NOT_AVAILABLE else NOT_AVAILABLE


## The figure in a line of that tool's output, in KiB, or NOT_AVAILABLE. tasklist prints it
## last, as "12,345 K", with the separator of the machine's language; ps prints bare KiB.
static func _kib_in(text: String, from_last_field: bool) -> int:
	var field: String = text.strip_edges()
	if from_last_field:
		field = field.split(',"')[-1] if field.contains(',"') else field
	var digits: String = ""
	for character: String in field:
		if character >= "0" and character <= "9":
			digits += character
	return int(digits) if not digits.is_empty() else NOT_AVAILABLE


static func texture_bytes() -> int:
	return int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))


static func video_bytes() -> int:
	return int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))


static func total_ram_bytes() -> int:
	var info: Dictionary = OS.get_memory_info()
	return int(info.get("physical", -1))


static func megabytes(bytes: int) -> String:
	return "%.1f MB" % (float(bytes) / (KIB * KIB))
