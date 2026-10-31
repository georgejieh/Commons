extends RefCounted
## Fixture: reaches an autoload by name.


func read_setting() -> StringName:
	return FixtureAutoload.get_class()
