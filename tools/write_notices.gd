extends SceneTree
## Writes Godot's license and third-party notices to the file --out names. Exits 1 when it
## cannot write it, 2 without --out. Run:
##   godot --headless --path . --script res://tools/write_notices.gd -- --out PATH

const USAGE: String = "write_notices.gd -- --out PATH"


func _initialize() -> void:
	var options: ToolOptions = ToolOptions.new(USAGE)
	if not options.has("out"):
		options.refuse("Needs --out PATH.")
	var out: String = options.path("out", "")
	if options.failed():
		quit(2)
		return
	var text: String = "Commons is built with Godot Engine.\n\n" + Engine.get_license_text()
	for component: Dictionary in Engine.get_copyright_info():
		text += "\n\n%s\n" % component["name"]
		for part: Dictionary in component["parts"]:
			text += "\n".join(part["copyright"]) + "\nLicense: %s\n" % part["license"]

	var licenses: Dictionary = Engine.get_license_info()
	for license_name: String in licenses:
		text += "\n\n%s\n\n%s" % [license_name, licenses[license_name]]

	quit(0 if ToolFiles.write(out, text) else 1)
