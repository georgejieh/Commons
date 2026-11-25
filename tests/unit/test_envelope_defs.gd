extends GdUnitTestSuite
## The envelope kinds in data (ADR 0021) pass the validator, and a broken one is caught.

const KINDS: Array[String] = ["directive_envelope", "campaign_envelope", "parcel", "deck_envelope"]

const DATA: String = "res://data/"
const STRINGS: String = "res://data/strings/strings.csv"
const FOLDER: String = "res://data/modifiers/envelopes/"


func _string_keys() -> Dictionary[String, bool]:
	var keys: Dictionary[String, bool] = {}
	var file: FileAccess = FileAccess.open(STRINGS, FileAccess.READ)
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if not row[0].is_empty():
			keys[row[0]] = true
	file.close()
	return keys


## An envelope kind missing its strings, cost, choices or weights, or holding a kind
## twice, is caught; the three kinds cost 4, open at tier 0 and show 3 each.
func test_envelopes_are_checked_and_hold_adr_0021s_numbers() -> void:
	var keys: Dictionary[String, bool] = _string_keys()
	for name: String in ["directive_envelope", "campaign_envelope", "parcel"]:
		var envelope: EnvelopeDef = load(DATA + "modifiers/envelopes/%s.tres" % name)
		assert_int(envelope.cost).is_equal(4)
		assert_int(envelope.unlock_tier).is_equal(0)
		assert_int(envelope.choices).is_equal(3)
		assert_str(tr(envelope.text_key)).contains("{choices}")
	var parcel: EnvelopeDef = load(DATA + "modifiers/envelopes/parcel.tres")
	assert_array(parcel.weights).is_equal([2, 1, 1])
	var bad: EnvelopeDef = parcel.duplicate()
	bad.cost = 0
	bad.choices = 0
	bad.name_key = "envelope.nothing_here.name"
	bad.weights = [2, 0]
	var problems: String = "\n".join(ModifierValidator.validate_envelope(bad, keys))
	for found: String in ["bad cost", "bad choices", "missing string key", "one weight"]:
		assert_str(problems).contains(found)
	var twice: EnvelopeDef = parcel.duplicate()
	twice.contents = [EnvelopeDef.Content.CAMPAIGN, EnvelopeDef.Content.CAMPAIGN]
	twice.weights = [1, 1]
	assert_str("\n".join(ModifierValidator.validate_envelope(twice, keys))).contains("content")
	var empty: EnvelopeDef = parcel.duplicate()
	empty.contents = []
	empty.weights = []
	assert_str("\n".join(ModifierValidator.validate_envelope(empty, keys))).contains("nothing")


## Every envelope in data is one of ADR 0021's three, and each passes the validator.
func test_every_envelope_in_data_is_valid() -> void:
	var keys: Dictionary[String, bool] = _string_keys()
	var found: Array[String] = []
	for file: String in DirAccess.get_files_at(FOLDER):
		if file.get_extension() != "tres":
			continue
		var envelope: EnvelopeDef = load(FOLDER + file)
		found.append(envelope.id)
		assert_array(Array(ModifierValidator.validate_envelope(envelope, keys))).is_empty()
	assert_array(found).contains_exactly_in_any_order(KINDS)
