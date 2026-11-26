class_name FaceCrop
extends RefCounted
## A portrait cropped to the box it is shown in, centred on the face.

## Space kept around a face in a portrait box, as a share of the head's size per side.
const FACE_MARGIN: float = 0.12


## A portrait cropped to a box of aspect (width / height), centered on the face.
static func crop(picture: Texture2D, face: Rect2, aspect: float) -> Texture2D:
	var made: AtlasTexture = AtlasTexture.new()
	made.atlas = picture
	made.region = region(picture.get_size(), face, aspect)
	return made


## The pixel region of an image of size that shows the whole face (fractions of the
## image) with a margin, at the given aspect, centered on the face and kept inside the
## image.
static func region(size: Vector2, face: Rect2, aspect: float) -> Rect2:
	var head: Rect2 = Rect2(face.position * size, face.size * size)
	var want: Vector2 = head.size * (1.0 + 2.0 * FACE_MARGIN)
	if want.x / want.y < aspect:
		want.x = want.y * aspect
	else:
		want.y = want.x / aspect
	var fit: float = minf(1.0, minf(size.x / want.x, size.y / want.y))
	want *= fit
	var corner: Vector2 = head.get_center() - want / 2.0
	corner = corner.clamp(Vector2.ZERO, size - want)
	return Rect2(corner, want)
