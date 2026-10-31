extends RefCounted
## Fixture: uses an engine singleton.


func platform() -> String:
	return OS.get_name()
