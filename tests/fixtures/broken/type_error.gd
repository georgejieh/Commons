extends RefCounted
## Fixture: does not compile.


func mismatch() -> int:
	var number: int = "text"
	return number
