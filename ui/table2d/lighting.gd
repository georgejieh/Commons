class_name Lighting
extends RefCounted
## 2D lighting for the table (P3C.6). A texture is lit by pairing it with its normal map,
## found by name: art/normals/<name>_n.png for art/.../<name>.png. Every stage version
## has its own, so the relief always matches the art shown. Only items on MASK take
## the table light, so labels and controls are never lit.

const MASK: int = 2
const NORMALS: String = "res://art/normals/%s_n.png"
const LIGHT_TEXTURE_SIZE: int = 256

static var _lit: Dictionary[Texture2D, Texture2D] = {}


## texture with its normal map, or texture itself when it has none.
static func lit(texture: Texture2D) -> Texture2D:
	if texture == null or texture.resource_path.is_empty():
		return texture
	if _lit.has(texture):
		return _lit[texture]
	var made: Texture2D = texture
	var normal_path: String = NORMALS % texture.resource_path.get_file().get_basename()
	if ResourceLoader.exists(normal_path):
		var canvas: CanvasTexture = CanvasTexture.new()
		canvas.diffuse_texture = texture
		canvas.normal_texture = load(normal_path)
		made = canvas
	_lit[texture] = made
	return made


## The texture behind a lit one.
static func diffuse(texture: Texture2D) -> Texture2D:
	var canvas: CanvasTexture = texture as CanvasTexture
	return canvas.diffuse_texture if canvas != null else texture


## A point light built from params, lighting MASK only.
static func light(params: TableLight) -> PointLight2D:
	var made: PointLight2D = PointLight2D.new()
	var glow: GradientTexture2D = GradientTexture2D.new()
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	glow.width = LIGHT_TEXTURE_SIZE
	glow.height = LIGHT_TEXTURE_SIZE
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	glow.gradient = fade
	made.texture = glow
	made.color = params.color
	made.energy = params.energy
	made.height = params.height
	made.range_item_cull_mask = MASK
	return made
