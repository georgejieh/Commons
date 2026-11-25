extends SceneTree
## Renders every card face, composed from its parts, into one sheet for checking by eye,
## then again under the table light, to compare with the unlit sheet. Needs a real
## renderer; it runs in the cloud playtest so no window opens locally:
##   godot --path . --script res://tools/card_faces.gd -- --out reports/card_faces
## Development only; tools/ never ships.

const USAGE: String = "card_faces.gd -- [--out DIR]"
const DEFAULT_OUT: String = "reports/card_faces"
const COLUMNS: int = 13
const GAP: Vector2 = Vector2(8, 12)
const SETTLE_FRAMES: int = 10

var _out: String
var _options: ToolOptions


func _initialize() -> void:
	_options = ToolOptions.new(USAGE)
	_out = _options.path("out", DEFAULT_OUT)
	if _options.failed():
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color("3a2a20")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var scene: PackedScene = load("res://ui/cards/card_view.tscn")
	for deck_id: int in Deck.SIZE:
		var view: Control = scene.instantiate()
		root.add_child(view)
		var cell: Vector2 = view.custom_minimum_size + GAP
		@warning_ignore("integer_division")
		view.position = GAP + Vector2(deck_id % COLUMNS, deck_id / COLUMNS) * cell
		view.call("bind", Deck.new().card(deck_id))
	for _frame: int in SETTLE_FRAMES:
		await process_frame
	var saved: bool = await _shot("all_faces")
	var params: TableLight = load("res://data/ui/table_light.tres")
	var light: PointLight2D = Lighting.light(params)
	light.position = Vector2(root.size) * params.position
	light.texture_scale = root.size.x * params.reach / Lighting.LIGHT_TEXTURE_SIZE
	root.add_child(light)
	for _frame: int in SETTLE_FRAMES:
		await process_frame
	saved = await _shot("all_faces_lit") and saved
	quit(0 if saved else 1)


## Saves the window's picture as name.png in the out folder; false when it could not.
func _shot(name: String) -> bool:
	print("FRAME %s" % name)
	await RenderingServer.frame_post_draw
	return ToolFiles.save_png(root.get_texture().get_image(), _out.path_join(name + ".png"))
