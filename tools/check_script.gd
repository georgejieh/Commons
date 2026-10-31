extends SceneTree
## Exits 1 if the script at the path given after `--` does not compile. Tests use it
## to prove the compile gate fails, in a process where a broken script can't fail them.


func _initialize() -> void:
	quit(0 if ScriptCheck.compiles(OS.get_cmdline_user_args()[0]) else 1)
