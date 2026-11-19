extends GdUnitTestSuite
## The table at its worst (ADR 0034): at each text size, at 1920x1080 and at 1280x800,
## every text piece holds the longest string of its family, measured in its own type,
## the debuff strip holds the three tallest debuffs, the trick a twenty-card play, the
## hand twenty cards and the Campaign tray three leaflets. Every piece is wholly on screen
## and no two pieces overlap, but for the pairs named below. ClipCheck sees each control
## against its own box and so cannot see one piece grow into another.
##
## The sheets that lie over the table on purpose (the need panel, the audit slip, the
## call-outs, the pause menu, the reading and rank pickers and tooltips) are left out of
## the pairwise rule; the need panel and the pause menu are checked on screen here, the
## rest in their own suites.

const SEED: int = 4301
const SAVE_PATH: String = "user://test_table_worst_case/run.json"
const SCREENS_AT: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 800)]
const SLACK: float = 1.5
## Pairs that may overlap by design, by name, and why. None today.
const ALLOWED: Dictionary[String, String] = {}
## Pairs that overlap and wait on a layout decision ADR 0034's rules do not settle, at
## every size or, after "@", at one. The three tallest debuffs need a 314 px strip at
## Standard and 484 px at Largest; the strip has 96 px between its top and the trick's
## area. At Largest the left seat (294 px), the tray at rest (196 px) and the brigade
## notice (169 px) need 29 px more than the 634 px from the seat's top to the notice's
## foot: the seat lies over the tray's head.
const UNSETTLED: Dictionary[String, String] = {
	"debuff strip|trick pile": "no room for three debuffs above the pile at any size",
	"debuff strip|status line@2": "the same strip runs on down to the status line",
	"left seat|Campaign tray@2": "the left column is 29 px short at Largest",
}

var _app: DemoApp
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)
	_app.new_run(SEED)
	# The pieces at rest: no swell or stamp caught halfway.
	Settings.set_value("reduced_motion", true)


func after_test() -> void:
	Settings.set_value(TextSize.SETTING, 0)
	Settings.set_value("reduced_motion", false)
	get_tree().root.size = _was_size
	Saves.run_service().delete()


func test_no_two_pieces_meet_and_each_is_on_screen_at_every_size() -> void:
	var problems: PackedStringArray = []
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		for screen: Vector2i in SCREENS_AT:
			get_tree().root.size = screen
			var table: TableScreen = await TableWorstCase.open(_app, self)
			for bidding: bool in [false, true]:
				TableWorstCase.fill(_app, table, bidding, bidding)
				await await_idle_frame()
				await await_idle_frame()
				var where: String = (
					"size %d on %s, %s"
					% [level, screen, "bidding, redacted" if bidding else "playing"]
				)
				_check(TableWorstCase.pieces(table), level, where, problems)
				ClipCheck.check(table, where, problems)
			await _check_sheets(table, "size %d on %s" % [level, screen], problems)
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()


## The worst case is the worst: each piece's string is the longest of its family.
func test_the_strings_are_the_longest_of_their_families() -> void:
	var table: TableScreen = await TableWorstCase.open(_app, self)
	TableWorstCase.fill(_app, table, false, false)
	await await_idle_frame()
	var seats: Dictionary[int, SeatPanel] = table.get("_seats")
	var role: Label = seats[1].get("_role")
	var font: Font = role.get_theme_font("font")
	var font_size: int = role.get_theme_font_size("font_size")
	var shown: float = font.get_string_size(role.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	for line: String in TableWorstCase.role_lines():
		var wide: float = (
			font.get_string_size(line.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		)
		assert_float(wide).override_failure_message(line).is_less_equal(shown)
	var prompt: Label = table.actions().reading
	assert_int(prompt.get_line_count()).is_greater_equal(2)
	var strip: DebuffStrip = table.get("_debuffs")
	for debuff_id: String in _app.controller.active_debuff_ids():
		assert_str(strip.shown_text()).contains(_app.controller.modifier_name(debuff_id))
	assert_int(_app.controller.active_debuff_ids().size()).is_equal(3)
	var campaigns: TableCampaigns = table.get("_campaigns")
	assert_int(campaigns.tray.campaign_count()).is_equal(TableWorstCase.TRAY_SIZE)
	var pile: TrickPile = table.get("_pile")
	assert_int(pile.card_count()).is_equal(TableWorstCase.MOST_CARDS)


func _check(
	pieces: Dictionary[String, Rect2], level: int, where: String, problems: PackedStringArray
) -> void:
	var screen: Rect2 = get_tree().root.get_visible_rect().grow(SLACK)
	var names: Array[String] = []
	names.assign(pieces.keys())
	for name: String in names:
		if not screen.encloses(pieces[name]):
			problems.append("%s: %s off screen at %s" % [where, name, pieces[name]])
	for first: int in names.size():
		for second: int in range(first + 1, names.size()):
			var pair: String = "%s|%s" % [names[first], names[second]]
			if ALLOWED.has(pair) or UNSETTLED.has(pair) or UNSETTLED.has("%s@%d" % [pair, level]):
				continue
			var a: Rect2 = pieces[names[first]].grow(-SLACK / 2.0)
			var b: Rect2 = pieces[names[second]].grow(-SLACK / 2.0)
			if a.has_area() and b.has_area() and a.intersects(b):
				problems.append(
					(
						"%s: %s %s meets %s %s"
						% [
							where,
							names[first],
							pieces[names[first]],
							names[second],
							pieces[names[second]]
						]
					)
				)


## The sheets laid over the table on purpose stay whole on the screen and do not clip.
func _check_sheets(table: TableScreen, where: String, problems: PackedStringArray) -> void:
	var screen: Rect2 = get_tree().root.get_visible_rect().grow(SLACK)
	var need: NeedPanel = table.need_panel()
	need.visible = true
	need.ask(9999, TableWorstCase.longest_surname(), 0.5)
	await await_idle_frame()
	if not screen.encloses(need.get_global_rect()):
		problems.append("%s: need panel off screen at %s" % [where, need.get_global_rect()])
	ClipCheck.check(need, where + " need panel", problems)
	need.visible = false
	table.call("_open_pause")
	await await_idle_frame()
	var pause: PauseMenu = table.get("_pause")
	ClipCheck.check(pause, where + " pause", problems)
	pause.close()
	await await_idle_frame()
