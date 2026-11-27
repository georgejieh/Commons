extends GdUnitTestSuite
## The table at its worst (ADR 0034): at each text size, at 1920x1080 and at 1280x800,
## every text piece holds the longest string of its family, measured in its own type, the
## trick a twenty-card play, the hand twenty cards and the Campaign tray three leaflets,
## with and without the tallest intel on both seats and with and without a Campaign
## armed. The rules slip holds the worst boss (ADR 0043) and either the three debuffs
## that stand tallest in full, or the most it can ever name: the longest names, every
## table-rule Reform, table-wide Cadres on the board and two wild ranks. Every piece is
## wholly on screen and no two pieces overlap. ClipCheck sees each control against its
## own box and so cannot see one piece grow into another.
##
## Which form the slip takes and which steps the left column takes are asserted for every
## case, so a string that flips one is seen.
##
## The sheets that lie over the table on purpose (the need panel, the audit slip, the
## call-outs, the pause menu, the reading and rank pickers and tooltips) are left out of
## the pairwise rule; the need panel and the pause menu are checked on screen here, the
## rest in their own suites.

const SEED: int = 4301
const SCREENS_AT: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 800)]
## Pairs that may overlap by design, by name, and why. None: ADR 0034's rules 6 to 10 make
## room for everything.
const ALLOWED: Dictionary[String, String] = {}
## The trick's place at 9cc9ecf, which it never leaves.
const TRICK_AT: Vector2 = Vector2(470, 380)
## For each slip case, size, intel and armed tray, the same on both screens: the slip's
## form, then whether the tray keeps its heading and the notice stays up, then each
## seat's intel type, the slip's type and its room.
const EXPECTED: Dictionary[String, String] = {
	"full|0|false|false": "NAMED heading:true notice:true intel:17/17 slip:20 room:345",
	"full|0|false|true": "NAMED heading:false notice:true intel:17/17 slip:20 room:345",
	"full|0|true|false": "NAMED heading:false notice:false intel:17/17 slip:20 room:226",
	"full|0|true|true": "NAMED heading:false notice:false intel:17/17 slip:20 room:226",
	"full|1|false|false": "NAMED heading:true notice:true intel:20/20 slip:23 room:320",
	"full|1|false|true": "NAMED heading:false notice:false intel:20/20 slip:23 room:320",
	"full|1|true|false": "NAMED heading:false notice:false intel:20/20 slip:23 room:185",
	"full|1|true|true": "NAMED heading:false notice:false intel:19/20 slip:23 room:185",
	"full|2|false|false": "NAMED heading:false notice:true intel:22/22 slip:26 room:288",
	"full|2|false|true": "NAMED heading:false notice:false intel:22/22 slip:26 room:288",
	"full|2|true|false": "COUNTED heading:false notice:false intel:21/17 slip:26 room:169",
	"full|2|true|true": "COUNTED heading:false notice:false intel:17/17 slip:26 room:169",
	"named|0|false|false": "NAMED heading:true notice:true intel:17/17 slip:20 room:345",
	"named|0|false|true": "NAMED heading:false notice:true intel:17/17 slip:20 room:345",
	"named|0|true|false": "COUNTED heading:false notice:false intel:17/17 slip:20 room:226",
	"named|0|true|true": "COUNTED heading:false notice:false intel:17/17 slip:20 room:226",
	"named|1|false|false": "FITTED heading:true notice:true intel:20/20 slip:22 room:320",
	"named|1|false|true": "FITTED heading:false notice:false intel:20/20 slip:22 room:320",
	"named|1|true|false": "COUNTED heading:false notice:false intel:20/17 slip:23 room:201",
	"named|1|true|true": "COUNTED heading:false notice:false intel:19/17 slip:23 room:201",
	"named|2|false|false": "COUNTED heading:false notice:true intel:22/22 slip:26 room:288",
	"named|2|false|true": "COUNTED heading:false notice:false intel:22/22 slip:26 room:288",
	"named|2|true|false": "COUNTED heading:false notice:false intel:21/17 slip:20 room:169",
	"named|2|true|true": "COUNTED heading:false notice:false intel:17/17 slip:20 room:169",
}
## The text sizes at which arming a Campaign puts the left seat's intel away.
const EXPECTED_AWAY: Array[int] = [2]

var _app: App
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	Saves.use_run_path(TestFolder.of("test_table_worst_case") + "run.json")
	Saves.run_service().delete()
	_app = AppKit.make(self)
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
	var seen: Dictionary[String, String] = {}
	for named: bool in [false, true]:
		for level: int in TextSize.count():
			Settings.set_value(TextSize.SETTING, level)
			for screen: Vector2i in SCREENS_AT:
				get_tree().root.size = screen
				var table: TableScreen = await TableWorstCase.open(_app, self, named)
				var case: String = (
					"%s|%d|%dx%d" % ["named" if named else "full", level, screen.x, screen.y]
				)
				await _each_state(table, case, named, seen, problems)
				await _check_sheets(table, case, problems)
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()
	var lines: PackedStringArray = []
	for key: String in seen:
		lines.append('\t"%s": "%s",' % [key, seen[key]])
	assert_dict(seen).override_failure_message("seen:\n" + "\n".join(lines)).is_equal(EXPECTED)


func _each_state(
	table: TableScreen,
	case: String,
	named: bool,
	seen: Dictionary[String, String],
	problems: PackedStringArray
) -> void:
	for intel: bool in [false, true]:
		for armed: bool in [false, true]:
			for bidding: bool in [false, true]:
				var options: Dictionary = {
					"bidding": bidding,
					"redacted": bidding,
					"wild": named,
					"intel": intel,
					"armed": armed,
				}
				TableWorstCase.fill(_app, table, options)
				await await_idle_frame()
				await await_idle_frame()
				var where: String = (
					"%s intel %s armed %s bidding %s" % [case, intel, armed, bidding]
				)
				if armed and table.campaigns.tray.armed_slot() < 0:
					problems.append("%s: no Campaign could be armed" % where)
				# The slip's last step, counted, must fit too: nothing gives way after it.
				if not table.debuffs.fits():
					problems.append("%s: the slip does not fit its room" % where)
				_check(TableWorstCase.pieces(table), where, problems)
				_note_column(table, where, problems)
				ClipCheck.check(table, where, problems)
				var pile: TrickPile = table.pile
				if not pile.position.is_equal_approx(TRICK_AT):
					problems.append("%s: the trick moved to %s" % [where, pile.position])
				# One answer per case, whatever the screen and whoever is bidding.
				var key: String = "%s|%s|%s" % [case.rsplit("|", true, 1)[0], intel, armed]
				var steps: String = _steps(table)
				if seen.get(key, steps) != steps:
					problems.append("%s: %s, but %s before" % [where, steps, seen[key]])
				seen[key] = steps


## Numbers for a left column that does not fit even after its last step.
func _note_column(table: TableScreen, where: String, problems: PackedStringArray) -> void:
	var seats: Dictionary[int, SeatPanel] = table.seats
	var campaigns: TableCampaigns = table.campaigns
	var tray: CampaignTray = campaigns.tray
	var foot: float = tray.position.y + tray.standing_height(tray.has_heading())
	if foot > DreadDressing.NOTICE_AT.end.y:
		problems.append(
			(
				"%s: left seat %.0f tall (intel %d px), tray %.0f to %.0f, notice foot %.0f"
				% [
					where,
					seats[2].get_combined_minimum_size().y,
					seats[2].intel_size(),
					tray.position.y,
					foot,
					DreadDressing.NOTICE_AT.end.y
				]
			)
		)


## The slip's form, the tray's heading, the notice and each seat's intel type, in words.
func _steps(table: TableScreen) -> String:
	var strip: DebuffStrip = table.debuffs
	var campaigns: TableCampaigns = table.campaigns
	var dressing: DreadDressing = table.dressing
	var seats: Dictionary[int, SeatPanel] = table.seats
	return (
		"%s heading:%s notice:%s intel:%d/%d slip:%d room:%d"
		% [
			DebuffStrip.Form.keys()[strip.form()],
			campaigns.tray.has_heading(),
			not dressing.is_notice_down(),
			seats[2].intel_size(),
			seats[1].intel_size(),
			strip.type_size(),
			roundi(strip.room),
		]
	)


## With no rule in force, no intel and nothing armed, at Standard, everything stands where
## it stood at 9cc9ecf: the tray under the seat with its heading, the notice up, the
## trick, the column and the hand in their places, and no slip.
func test_a_table_with_no_rule_stands_as_before_at_standard() -> void:
	var loop: RunLoop = _app.controller.run_loop()
	loop.state.inventory.consumables.assign(["mutual_aid"])
	for screen: Vector2i in SCREENS_AT:
		get_tree().root.size = screen
		var table: TableScreen = _app.show_screen(App.TABLE, true)
		await await_idle_frame()
		await await_idle_frame()
		var campaigns: TableCampaigns = table.campaigns
		var dressing: DreadDressing = table.dressing
		var strip: DebuffStrip = table.debuffs
		var pile: TrickPile = table.pile
		assert_bool(strip.visible).is_false()
		assert_vector(pile.position).is_equal(TRICK_AT)
		assert_bool(campaigns.tray.visible and campaigns.tray.has_heading()).is_true()
		assert_float(campaigns.tray.position.y).is_equal(367.0)
		assert_bool(dressing.is_notice_down()).is_false()
		assert_bool(dressing.notice_rect().is_equal_approx(DreadDressing.NOTICE_AT)).is_true()
		var held: Rect2 = table.actions.held()
		assert_bool(held.is_equal_approx(Rect2(1218, 780, 330, 250))).is_true()
		var hand: HandView = table.hand_view
		assert_bool(hand.get_global_rect().is_equal_approx(TableScreen.HAND_AT)).is_true()


## The Rules sheet has every rule the slip can name or count, in full: in the named worst
## case each debuff, table-wide Cadre and table-rule Reform with its rule text.
func test_the_rules_sheet_has_every_rule_in_force_in_full() -> void:
	var table: TableScreen = await TableWorstCase.open(_app, self, true)
	TableWorstCase.fill(_app, table, {"wild": true})
	var sheet: CheatSheet = table.cheat_sheet
	sheet.toggle(_app.controller)
	await await_idle_frame()
	var shown: String = sheet.active_text()
	var ids: Array[String] = _app.controller.items.active_modifier_ids()
	assert_int(ids.size()).is_greater(3)
	for modifier_id: String in ids:
		assert_str(shown).contains(_app.controller.texts.modifier_name(modifier_id))
		assert_str(shown).contains(_app.controller.texts.modifier_text(modifier_id))
	var reforms: Array[String] = _app.controller.items.table_rule_reforms()
	assert_int(reforms.size()).is_greater(0)
	for reform_id: String in reforms:
		assert_str(shown).contains(_app.controller.texts.reform_name(reform_id))
		assert_str(shown).contains(_app.controller.texts.reform_text(reform_id))


## The worst case is the worst: each piece's string is the longest of its family.
func test_the_strings_are_the_longest_of_their_families() -> void:
	var table: TableScreen = await TableWorstCase.open(_app, self)
	TableWorstCase.fill(_app, table, {})
	await await_idle_frame()
	var seats: Dictionary[int, SeatPanel] = table.seats
	var role: Label = seats[1].role
	var font: Font = role.get_theme_font("font")
	var font_size: int = role.get_theme_font_size("font_size")
	var shown: float = font.get_string_size(role.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	for line: String in TableWorstCase.role_lines():
		var wide: float = (
			font.get_string_size(line.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		)
		assert_float(wide).override_failure_message(line).is_less_equal(shown)
	var prompt: Label = table.actions.reading
	assert_int(prompt.get_line_count()).is_greater_equal(2)
	var strip: DebuffStrip = table.debuffs
	for debuff_id: String in _app.controller.items.active_debuff_ids():
		assert_str(strip.shown_text()).contains(_app.controller.texts.modifier_name(debuff_id))
	assert_int(_app.controller.items.active_debuff_ids().size()).is_equal(3)
	assert_float(strip.size.x).is_equal(TableWorstCase.STRIP_WIDTH)
	var campaigns: TableCampaigns = table.campaigns
	assert_int(campaigns.tray.campaign_count()).is_equal(TableWorstCase.TRAY_SIZE)
	var pile: TrickPile = table.pile
	assert_int(pile.card_count()).is_equal(TableWorstCase.MOST_CARDS)
	assert_int(_app.hand.cards().size()).is_equal(TableWorstCase.MOST_CARDS)


## The slip stands in front of the room's dressing, the right chair included, and the
## moments layer, where the dice bowl lands, lies over the slip.
func test_the_slip_draws_over_the_dressing_and_under_the_moments() -> void:
	var table: TableScreen = _app.show_screen(App.TABLE, true)
	await await_idle_frame()
	var dressing: Control = table.dressing
	var strip: Control = table.debuffs
	var moments: TableMoments = table.moments
	assert_int(dressing.get_index()).is_less(strip.get_index())
	assert_int(strip.get_index()).is_less(moments.get_index())
	assert_bool(moments.is_ancestor_of(moments.dice)).is_true()


## Rule 8's last step: with intel on the left seat, arming a Campaign puts the intel away
## only when the column is still short after the heading, the notice and the intel's type;
## putting the Campaign down brings the intel back. Using it ends the arming through the
## same signal, but its moment reads the seats afresh, which clears the staged intel.
func test_an_armed_campaign_puts_the_intel_away_only_when_still_short() -> void:
	var away_at: Array[int] = []
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		var table: TableScreen = await TableWorstCase.open(_app, self)
		TableWorstCase.fill(_app, table, {"intel": true})
		await await_idle_frame()
		var seats: Dictionary[int, SeatPanel] = table.seats
		var left: SeatPanel = seats[2]
		assert_bool(left.has_intel()).is_true()
		var columns: TableColumns = table.columns
		var campaigns: TableCampaigns = table.campaigns
		var tray: CampaignTray = campaigns.tray
		var short: bool = _short_when_armed(columns, tray, left)
		TableWorstCase.fill(_app, table, {"intel": true, "armed": true})
		await await_idle_frame()
		var away: bool = not left.intel_line.text.is_empty() and not left.intel_line.visible
		assert_bool(away).override_failure_message(str(level)).is_equal(short)
		assert_bool(left.has_intel()).is_equal(not short)
		if short:
			away_at.append(level)
		tray.disarm()
		await await_idle_frame()
		assert_bool(left.has_intel()).override_failure_message("put down").is_true()
	assert_array(away_at).is_equal(EXPECTED_AWAY)


## Whether an armed tray would still overflow with the intel at its Standard size.
func _short_when_armed(columns: TableColumns, tray: CampaignTray, left: SeatPanel) -> bool:
	assert_int(TableWorstCase.arm(tray)).is_greater_equal(0)
	# Arming lays the column out, which may put the intel away: it is measured shown.
	left.put_away_intel(false)
	left.fit_intel(TextSize.least(SeatPanel.INTEL_SIZE))
	var foot: float = left.position.y + left.get_combined_minimum_size().y + 4.0
	var top: float = maxf(TableCampaigns.TRAY_AT.y, foot)
	var short: bool = top + tray.standing_height(false) > DreadDressing.NOTICE_AT.end.y
	tray.disarm()
	columns.fit()
	return short


## The columns are laid out on the table's own moments, never on a size change they made:
## in the worst case, with intel on both seats and a Campaign armed, the layout is the same
## frame after frame and the count of layouts stops.
func test_the_columns_settle_and_stop_laying_out() -> void:
	Settings.set_value(TextSize.SETTING, TextSize.count() - 1)
	var table: TableScreen = await TableWorstCase.open(_app, self, true)
	TableWorstCase.fill(_app, table, {"intel": true, "armed": true, "wild": true})
	for frame: int in 3:
		await await_idle_frame()
	var columns: TableColumns = table.columns
	var first: String = _layout(table)
	var count: int = columns.refits
	for frame: int in 10:
		await await_idle_frame()
		assert_str(_layout(table)).override_failure_message(str(frame)).is_equal(first)
	assert_int(columns.refits).is_equal(count)


func _layout(table: TableScreen) -> String:
	var seats: Dictionary[int, SeatPanel] = table.seats
	var strip: DebuffStrip = table.debuffs
	var campaigns: TableCampaigns = table.campaigns
	return (
		"%s %s %s %s %s"
		% [
			seats[2].get_global_rect(),
			seats[1].get_global_rect(),
			strip.get_global_rect(),
			campaigns.tray.position,
			_steps(table),
		]
	)


func _check(pieces: Dictionary[String, Rect2], where: String, problems: PackedStringArray) -> void:
	var screen: Rect2 = get_tree().root.get_visible_rect().grow(ClipCheck.SLACK)
	var names: Array[String] = []
	names.assign(pieces.keys())
	for piece: String in names:
		if not screen.encloses(pieces[piece]):
			problems.append("%s: %s off screen at %s" % [where, piece, pieces[piece]])
	for first: int in names.size():
		for second: int in range(first + 1, names.size()):
			var pair: String = "%s|%s" % [names[first], names[second]]
			if ALLOWED.has(pair):
				continue
			var a: Rect2 = pieces[names[first]].grow(-ClipCheck.SLACK / 2.0)
			var b: Rect2 = pieces[names[second]].grow(-ClipCheck.SLACK / 2.0)
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
	var screen: Rect2 = get_tree().root.get_visible_rect().grow(ClipCheck.SLACK)
	var need: NeedPanel = table.need_panel
	need.visible = true
	need.ask(9999, TableWorstCase.longest_surname(_app.controller), 0.5)
	await await_idle_frame()
	if not screen.encloses(need.get_global_rect()):
		problems.append("%s: need panel off screen at %s" % [where, need.get_global_rect()])
	ClipCheck.check(need, where + " need panel", problems)
	need.visible = false
	table.hud.menu.pressed.emit()
	await await_idle_frame()
	var pause: PauseMenu = table.pause
	ClipCheck.check(pause, where + " pause", problems)
	pause.close()
	await await_idle_frame()
