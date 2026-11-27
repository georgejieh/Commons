extends GdUnitTestSuite
## Every villager portrait shows its whole face, centered in its box (P3B.8, P4.5). Each
## portrait has a face rectangle in data; the crop for every box shape must contain it
## and stay inside the image.

const DEMO: DemoParams = preload("res://data/run/demo.tres")
const VILLAGE: VillageBook = preload("res://data/villagers/village.tres")
## The portrait boxes in use: the seat panel and the dossier.
const BOXES: Array[Vector2] = [Vector2(102, 130), Vector2(150, 188)]
const UNIT: Rect2 = Rect2(0, 0, 1, 1)


## Every portrait in use, as [label, texture, face]: the demo's seats and every family
## and youth template in the village (P4.5).
func _portraits() -> Array[Array]:
	var found: Array[Array] = []
	for seat: int in DEMO.portraits.size():
		if DEMO.portraits[seat] != null:
			found.append(["seat %d" % seat, DEMO.portraits[seat], DEMO.portrait_faces[seat]])
	for family: FamilyDef in VILLAGE.families + VILLAGE.youth_templates:
		found.append([family.id, family.portrait, family.portrait_face])
	return found


func test_every_portrait_has_a_face_inside_its_image() -> void:
	assert_int(DEMO.portrait_faces.size()).is_equal(DEMO.portraits.size())
	for portrait: Array in _portraits():
		var where: String = portrait[0]
		assert_object(portrait[1]).override_failure_message(where).is_not_null()
		var face: Rect2 = portrait[2]
		assert_bool(face.has_area()).override_failure_message(where).is_true()
		assert_bool(UNIT.encloses(face)).override_failure_message(where).is_true()


func test_every_crop_holds_the_whole_face_near_its_center() -> void:
	for portrait: Array in _portraits():
		if portrait[1] == null:
			continue
		var texture: Texture2D = portrait[1]
		var size: Vector2 = texture.get_size()
		var face: Rect2 = portrait[2]
		var head: Rect2 = Rect2(face.position * size, face.size * size)
		for box: Vector2 in BOXES:
			var region: Rect2 = ScreenKit.face_region(size, face, box.x / box.y)
			var where: String = "%s box %s" % [portrait[0], box]
			(
				assert_bool(Rect2(Vector2.ZERO, size).encloses(region))
				. override_failure_message(where)
				. is_true()
			)
			assert_bool(region.grow(0.5).encloses(head)).override_failure_message(where).is_true()
			var off: float = absf(region.get_center().x - head.get_center().x) / region.size.x
			assert_float(off).override_failure_message(where).is_less(0.1)
			assert_float(region.size.x / region.size.y).is_equal_approx(box.x / box.y, 0.01)


## A face too near an edge still yields a crop inside the image.
func test_a_face_at_the_edge_stays_inside_the_image() -> void:
	var size: Vector2 = Vector2(600, 800)
	var region: Rect2 = ScreenKit.face_region(size, Rect2(0.7, 0.0, 0.3, 0.3), 0.8)
	assert_bool(Rect2(Vector2.ZERO, size).encloses(region)).is_true()
