extends RefCounted
## Fixture: reaches an autoload by name.


func read_autoload() -> StringName:
	return _mcp_game_helper.get_class()
