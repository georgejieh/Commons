class_name LongRun
extends RefCounted
## Sample sizes for heavy checks. The suite runs the short size. COMMONS_LONG=1 runs the
## size a checklist item names, which the nightly job and one-off verification use.


static func sample(short: int, full: int) -> int:
	return full if OS.get_environment("COMMONS_LONG") == "1" else short
