class_name PerfReport
extends RefCounted
## Writes the budget report: the machine's facts without a date, then one table.

const GIT_ARGS: PackedStringArray = ["rev-parse", "--short", "HEAD"]


## The date-free facts of this machine and build, as label and value.
static func machine_facts() -> Array[PackedStringArray]:
	var facts: Array[PackedStringArray] = []
	facts.append(PackedStringArray(["OS", "%s %s" % [OS.get_name(), OS.get_version()]]))
	facts.append(PackedStringArray(["Processor", OS.get_processor_name()]))
	facts.append(PackedStringArray(["Logical processors", str(OS.get_processor_count())]))
	var ram: int = PerfMemory.total_ram_bytes()
	var ram_text: String = PerfMemory.megabytes(ram) if ram > 0 else "unknown"
	facts.append(PackedStringArray(["Total RAM", ram_text]))
	var adapter: String = RenderingServer.get_video_adapter_name()
	facts.append(
		PackedStringArray(["Graphics adapter", adapter if not adapter.is_empty() else "none"])
	)
	var method: String = RenderingServer.get_current_rendering_method()
	facts.append(PackedStringArray(["Rendering method", method]))
	facts.append(PackedStringArray(["Display server", DisplayServer.get_name()]))
	facts.append(PackedStringArray(["Godot", String(Engine.get_version_info()["string"])]))
	var commit: String = _commit()
	if not commit.is_empty():
		facts.append(PackedStringArray(["Commit", commit]))
	return facts


static func markdown(
	rows: Array[PerfRow], facts: Array[PackedStringArray], run_line: String
) -> String:
	var lines: PackedStringArray = ["# Performance budget", ""]
	for fact: PackedStringArray in facts:
		lines.append("- %s: %s" % [fact[0], fact[1]])
	lines.append("- Run: %s" % run_line)
	lines.append("")
	lines.append("| Row | Budget | Measured | Result | Samples |")
	lines.append("| --- | --- | --- | --- | --- |")
	for row: PerfRow in rows:
		lines.append(row.table_line())
	lines.append("")
	lines.append(summary(rows))
	lines.append("")
	lines.append(
		(
			"NOT MEASURED is not a pass: nothing was measured for that row on this run. INFO is"
			+ " reported and not judged."
		)
	)
	return "\n".join(lines) + "\n"


static func summary(rows: Array[PerfRow]) -> String:
	var counts: Array[int] = [0, 0, 0, 0]
	for row: PerfRow in rows:
		counts[row.verdict] += 1
	return (
		"%d PASS, %d MISS, %d INFO, %d NOT MEASURED"
		% [
			counts[PerfRow.Verdict.PASS],
			counts[PerfRow.Verdict.MISS],
			counts[PerfRow.Verdict.INFO],
			counts[PerfRow.Verdict.NOT_MEASURED],
		]
	)


static func missed(rows: Array[PerfRow]) -> int:
	var count: int = 0
	for row: PerfRow in rows:
		count += 1 if row.verdict == PerfRow.Verdict.MISS else 0
	return count


static func _commit() -> String:
	var output: Array = []
	var args: PackedStringArray = ["-C", ProjectSettings.globalize_path("res://")]
	args.append_array(GIT_ARGS)
	if OS.execute("git", args, output, false) != 0 or output.is_empty():
		return ""
	return String(output[0]).strip_edges()
