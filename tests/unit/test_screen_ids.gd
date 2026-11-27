extends GdUnitTestSuite
## No script of the game, the screens, the tools or the tests names a screen by its string:
## each reads the id from ScreenId. A literal spelled like an id but meaning something else
## is not counted: a dictionary's key, a subscript, the member named to get, set, call or
## has_method, or to a walk's view, member or invoke, and the two names below. A literal
## before a colon is a key only when a value follows on its line and no condition leads
## it, so a match case and an if are still read.

const FOLDERS: Array[String] = ["res://ui", "res://game", "res://tools", "res://tests"]
const OWNER: String = "res://game/scenes/screen_id.gd"
## Literals that share a screen's spelling, by path, each with its reason.
const OTHER_NAMES: Dictionary[String, String] = {
	"res://game/autoload/settings.gd settings": "The settings file's section.",
	"res://game/save/profile_data.gd surname": "A field of the saved profile.",
}
## Text before a literal that makes it a member's name: the first argument of get, set,
## call or has_method, or the second of a walk's view, member or invoke.
const MEMBER_NAMED: String = (
	r"(?:\b(?:get|set|call|has_method)\(\s*" + r"|\b(?:view|member|invoke)\([^,\n]*,\s*)$"
)
const SUBSCRIPT: String = r"[\w\)\]]\[$"
const KEY_AFTER: String = r"^\s*:(?!=)\s*\S"
const CONDITION: String = r"\b(?:if|elif|while)\b"


func test_no_script_names_a_screen_by_its_string() -> void:
	var ids: Dictionary[String, bool] = _ids()
	assert_int(ids.size()).is_greater(20)
	var offences: PackedStringArray = []
	for path: String in SourceScan.files(FOLDERS, ["gd"]):
		if path != OWNER:
			offences.append_array(_offences(path, SourceScan.read(path), ids))
	assert_array(offences).override_failure_message("\n".join(offences)).is_empty()


func test_the_scan_catches_a_screen_named_by_its_string() -> void:
	var ids: Dictionary[String, bool] = _ids()
	var named: String = (
		"\n"
		. join(
			[
				'app.show_screen("%s")' % ScreenId.TABLE,
				'app.call("show_screen", "%s", true)' % ScreenId.STORE,
				'if switcher.current_id() == "%s":' % ScreenId.TITLE,
				'for screen_id: String in ["%s"]:' % ScreenId.DOSSIER,
				'\t"%s":' % ScreenId.ENDING,
			]
		)
	)
	var other: String = (
		"\n"
		. join(
			[
				'var fields: Dictionary = {"%s": 1}' % ScreenId.SURNAME,
				'var held: String = data["%s"]' % ScreenId.SURNAME,
				'var part: Object = app.get("%s")' % ScreenId.ARRIVAL,
				'var seats: Object = view(controller, "%s")' % ScreenId.TABLE,
				'# The "%s" screen.' % ScreenId.TABLE,
			]
		)
	)
	var caught: PackedStringArray = _offences("res://made_up.gd", named, ids)
	assert_array(caught).override_failure_message("\n".join(caught)).has_size(5)
	var missed: PackedStringArray = _offences("res://made_up.gd", other, ids)
	assert_array(missed).override_failure_message("\n".join(missed)).is_empty()


static func _ids() -> Dictionary[String, bool]:
	var ids: Dictionary[String, bool] = {}
	var constants: Dictionary = (load(OWNER) as Script).get_script_constant_map()
	for constant: String in constants:
		ids[str(constants[constant])] = true
	return ids


## Each literal of the code that is a screen's id, as "path:line: id".
static func _offences(
	path: String, text: String, ids: Dictionary[String, bool]
) -> PackedStringArray:
	var code: String = SourceScan.code_of(text)
	var offences: PackedStringArray = []
	for hit: RegExMatch in SourceScan.pattern(SourceScan.LITERAL).search_all(code):
		var value: String = hit.get_string(1) if hit.get_start(1) >= 0 else hit.get_string(2)
		if not ids.has(value) or OTHER_NAMES.has(path + " " + value):
			continue
		var line_start: int = code.rfind("\n", hit.get_start()) + 1
		var lead: String = code.substr(line_start, hit.get_start() - line_start)
		var keyed: bool = (
			SourceScan.pattern(KEY_AFTER).search(code.substr(hit.get_end(), 40)) != null
			and SourceScan.pattern(CONDITION).search(lead) == null
		)
		if (
			keyed
			or SourceScan.pattern(MEMBER_NAMED).search(lead) != null
			or SourceScan.pattern(SUBSCRIPT).search(lead) != null
		):
			continue
		offences.append("%s:%d: %s" % [path, SourceScan.line_of(code, hit.get_start()), value])
	return offences
