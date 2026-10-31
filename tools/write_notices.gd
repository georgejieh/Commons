extends SceneTree
## Writes Godot's license and third-party notices to the path given after `--`.


func _initialize() -> void:
	var text: String = "Commons is built with Godot Engine.\n\n" + Engine.get_license_text()
	for component: Dictionary in Engine.get_copyright_info():
		text += "\n\n%s\n" % component["name"]
		for part: Dictionary in component["parts"]:
			text += "\n".join(part["copyright"]) + "\nLicense: %s\n" % part["license"]

	var licenses: Dictionary = Engine.get_license_info()
	for license_name: String in licenses:
		text += "\n\n%s\n\n%s" % [license_name, licenses[license_name]]

	var file: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(text)
	file.close()
	quit()
