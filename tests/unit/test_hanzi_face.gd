extends GdUnitTestSuite
## The decorative Chinese face holds every character the data asks a seal to draw: each
## ending's seal and each family's hanzi (ADR 0024). The face is a subset cut from the
## data by tools/subset_hanzi_font.py, so a new family or seal fails here until it is cut
## again.

const ENDINGS: EndingParams = preload("res://data/run/endings.tres")
const FAMILIES: String = "res://data/villagers/families/"


func test_every_endings_seal_can_be_drawn() -> void:
	assert_object(ScreenKit.ART.hanzi_font).is_not_null()
	for ending: String in ENDINGS.seals:
		var seal: String = ENDINGS.seals[ending]
		assert_bool(HanziSeal.can_draw(seal)).override_failure_message(ending).is_true()


func test_every_familys_hanzi_can_be_drawn() -> void:
	var drawn: int = 0
	for file: String in DirAccess.get_files_at(FAMILIES):
		if not file.ends_with(".tres"):
			continue
		var family: FamilyDef = load(FAMILIES + file)
		if family.hanzi.is_empty():
			continue
		assert_bool(HanziSeal.can_draw(family.hanzi)).override_failure_message(file).is_true()
		drawn += 1
	assert_int(drawn).is_greater(0)
