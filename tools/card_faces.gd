extends SceneTree
## Renders all 54 card faces, composed from their parts (P3C.5), into one sheet for
## checking by eye, then again under the table light (P3C.6). Needs a real renderer;
## it runs in the cloud playtest so no window opens locally:
##   godot --path . --script res://tools/card_faces.gd -- --out reports/card_faces
## Development only; tools/ never ships.

const COLUMNS: int = 13
const DECK_SIZE: int = 54
const GAP: Vector2 = Vector2(8, 12)
const SETTLE_FRAMES: int = 10

var _out: String = "res://reports/card_faces"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find("--out")
	if at >= 0 and at + 1 < args.size():
		_out = "res://" + args[at + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_run.call_deferred()


func _run() -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color("3a2a20")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var scene: PackedScene = load("res://ui/cards/card_view.tscn")
	for deck_id: int in DECK_SIZE:
		var view: Control = scene.instantiate()
		root.add_child(view)
		var cell: Vector2 = view.custom_minimum_size + GAP
		view.position = GAP + Vector2(deck_id % COLUMNS, deck_id / COLUMNS) * cell
		view.call("bind", CardInstance.from_deck_id(deck_id))
	for _frame: int in SETTLE_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/all_faces.png" % _out)
	print("saved all_faces")
	# The same faces under the table light (P3C.6), to compare with the unlit sheet.
	var params: TableLight = load("res://data/ui/table_light.tres")
	var light: PointLight2D = Lighting.light(params)
	light.position = Vector2(root.size) * params.position
	light.texture_scale = root.size.x * params.reach / Lighting.LIGHT_TEXTURE_SIZE
	root.add_child(light)
	for _frame: int in SETTLE_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/all_faces_lit.png" % _out)
	print("saved all_faces_lit")
	quit(0)
