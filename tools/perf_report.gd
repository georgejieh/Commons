class_name PerfReport
extends RefCounted
## Writes the budget report: the machine's facts without a date, then one table.

const GIT_ARGS: PackedStringArray = ["rev-parse", "--short", "HEAD"]


## The date-free facts of this machine and build, each value under its label, in the
## order the report lists them.
static func machine_facts() -> Dictionary[String, String]:
	var facts: Dictionary[String, String] = {}
	facts["OS"] = "%s %s" % [OS.get_name(), OS.get_version()]
	facts["Processor"] = OS.get_processor_name()
	facts["Logical processors"] = str(OS.get_processor_count())
	var ram: int = PerfMemory.total_ram_bytes()
	facts["Total RAM"] = PerfMemory.megabytes(ram) if ram > 0 else "unknown"
	var adapter: String = RenderingServer.get_video_adapter_name()
	facts["Graphics adapter"] = adapter if not adapter.is_empty() else "none"
	facts["Rendering method"] = RenderingServer.get_current_rendering_method()
	facts["Display server"] = DisplayServer.get_name()
	facts["Godot"] = String(Engine.get_version_info()["string"])
	var commit: String = _commit()
	if not commit.is_empty():
		facts["Commit"] = commit
	return facts


## The whole report: facts, the line that says how it was run, then the rows.
static func markdown(
	rows: Array[PerfRow], facts: Dictionary[String, String], run_line: String
) -> String:
	var lines: PackedStringArray = ["# Performance budget", ""]
	for label: String in facts:
		lines.append("- %s: %s" % [label, facts[label]])
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


## The count of rows of each verdict, as one line.
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


## How many rows missed their budget.
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
