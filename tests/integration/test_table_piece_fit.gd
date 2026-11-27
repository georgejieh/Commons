extends GdUnitTestSuite
## Single pieces of the table at every text size (ADR 0034), so a failure names the
## piece: a seat with the longest of each line keeps its width and its landlord tag
## clear of its name, the tag never set under its Standard size; the action column keeps
## its foot and its width whatever the prompt says; and the rules sheet keeps a clear gap
## between its text and its scroll bar.

const SEED: int = 4301
const SCREENS_AT: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 800)]

var _app: App
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)
	_app.new_run(SEED)
	Settings.set_value("reduced_motion", true)


func after_test() -> void:
	Settings.set_value(TextSize.SETTING, 0)
	Settings.set_value("reduced_motion", false)
	get_tree().root.size = _was_size
	Saves.run_service().delete()


func test_a_seat_keeps_its_width_and_its_tag_clear_of_its_name() -> void:
	var problems: PackedStringArray = []
	var base: int = CommonsTheme.STYLE.eyebrow_size
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		var panel: SeatPanel = auto_free(SeatPanel.new())
		_app.add_child(panel)
		panel.position = Vector2(80, 112)
		panel.size = Vector2(TableScreen.SEAT_WIDTH, 0)
		panel.setup(2, TableWorstCase.longest_surname(_app.controller))
		panel.set_role(true, false)
		var role: Label = panel.role
		panel.set_bid(TableWorstCase.widest(role, TableWorstCase.role_lines(), true))
		panel.set_count(2)
		var speech: Label = panel.speech_line
		panel.say(TableWorstCase.widest(speech, TableWorstCase.speech_lines()))
		await await_idle_frame()
		await await_idle_frame()
		var where: String = "size %d" % level
		var banner_label: Label = panel.banner
		var name_label: Label = panel.name_label
		var tag: Rect2 = banner_label.get_global_rect()
		var name_rect: Rect2 = name_label.get_global_rect()
		if tag.intersects(name_rect):
			problems.append("%s: tag %s meets name %s" % [where, tag, name_rect])
		var banner: Label = panel.banner
		var tag_size: int = banner.get_theme_font_size("font_size")
		if tag_size < base or tag_size > TextSize.px(base):
			problems.append("%s: tag set at %d" % [where, tag_size])
		if not panel.get_global_rect().encloses(tag):
			problems.append("%s: tag %s off its seat" % [where, tag])
		if absf(panel.size.x - TableScreen.SEAT_WIDTH) > ClipCheck.SLACK:
			problems.append("%s: seat %.0f wide" % [where, panel.size.x])
			var pieces: Array[Control] = [
				panel.name_label,
				panel.count_row,
				panel.role,
				panel.speech_line,
				panel.info,
				panel.row
			]
			for piece: Control in pieces:
				problems.append("  %s min %s" % [piece, piece.get_combined_minimum_size()])
		ClipCheck.check(panel, where, problems)
		panel.queue_free()
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()


## At Standard the tag is the width it always was, its word at its Standard size.
func test_the_tag_is_unchanged_at_standard() -> void:
	var panel: SeatPanel = auto_free(SeatPanel.new())
	_app.add_child(panel)
	panel.setup(2, TableWorstCase.longest_surname(_app.controller))
	panel.set_role(true, false)
	await await_idle_frame()
	var banner: Label = panel.banner
	var base: int = CommonsTheme.STYLE.eyebrow_size
	assert_int(banner.get_theme_font_size("font_size")).is_equal(base)
	var font: Font = banner.get_theme_font("font")
	var word: float = font.get_string_size(banner.text, HORIZONTAL_ALIGNMENT_LEFT, -1, base).x
	var natural: float = maxf(SeatPanel.PORTRAIT_BOX.x, word + 2 * SeatPanel.TAG_MARGIN)
	var shown: Label = panel.banner
	assert_float(shown.get_global_rect().size.x).is_equal_approx(natural, 1.0)


## A seat that takes the landlord's seat and loses it before the stamp lands, as a resume
## replays it, shows no tag once the stamp's time has passed.
func test_a_tag_stamped_and_lost_at_once_stays_off() -> void:
	Settings.set_value("reduced_motion", false)
	var panel: SeatPanel = auto_free(SeatPanel.new())
	_app.add_child(panel)
	panel.setup(1, TableWorstCase.longest_surname(_app.controller))
	# As the table seats it: a peasant first, so taking the seat is stamped.
	panel.set_role(false, false)
	panel.set_role(true, false)
	panel.set_role(false, false)
	# Timed: that the tag stays off is seen over the time its stamp would have taken.
	await get_tree().create_timer(UiMotion.PRESETS.stamp_time + 0.2).timeout
	var banner: Label = panel.banner
	assert_float(banner.modulate.a).is_equal(0.0)
	panel.set_role(true, false)
	var stamped: Callable = func() -> bool:
		return banner.modulate.a == 1.0 and banner.scale == Vector2.ONE
	await TestWait.until(self, stamped, "the tag to be stamped")


func test_the_action_column_keeps_its_foot_and_width() -> void:
	var problems: PackedStringArray = []
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		for screen: Vector2i in SCREENS_AT:
			get_tree().root.size = screen
			var table: TableScreen = _app.show_screen(ScreenId.TABLE, true)
			await await_idle_frame()
			var actions: ActionBar = table.actions
			for bidding: bool in [false, true]:
				actions.show_bidding(bidding)
				var prompts: Array[String] = PromptLines.every(_app.controller, bidding)
				actions.say("")
				actions.say(TableWorstCase.tallest(actions.reading, prompts))
				await await_idle_frame()
				await await_idle_frame()
				var where: String = "size %d on %s, bidding %s" % [level, screen, bidding]
				_check_column(actions, where, problems)
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()


func _check_column(actions: ActionBar, where: String, problems: PackedStringArray) -> void:
	var column: Rect2 = actions.get_global_rect()
	var at: Rect2 = actions.held()
	if absf(column.end.y - at.end.y) > ClipCheck.SLACK:
		problems.append("%s: column foot at %.0f" % [where, column.end.y])
	if (
		absf(column.position.x - at.position.x) > ClipCheck.SLACK
		or column.size.x > at.size.x + ClipCheck.SLACK
	):
		problems.append("%s: column %s wider than %s" % [where, column, at])
		for child: Node in actions.find_children("*", "Control", true, false):
			var part: Control = child as Control
			if part.is_visible_in_tree():
				problems.append("  %s min %s" % [part.name, part.get_combined_minimum_size()])
	for button: Button in actions.find_children("*", "Button", true, false):
		if (
			button.is_visible_in_tree()
			and not column.grow(ClipCheck.SLACK).encloses(button.get_global_rect())
		):
			problems.append("%s: %s outside the column" % [where, button.text])
	ClipCheck.check(actions, where, problems)


func test_the_rules_sheet_keeps_a_gap_at_its_scroll_bar() -> void:
	var problems: PackedStringArray = []
	var scrolled: int = 0
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		for screen: Vector2i in SCREENS_AT:
			get_tree().root.size = screen
			var table: TableScreen = _app.show_screen(ScreenId.TABLE, true)
			await await_idle_frame()
			var sheet: CheatSheet = table.cheat_sheet
			sheet.toggle(_app.controller)
			await await_idle_frame()
			await await_idle_frame()
			var scroll: ProseScroll = sheet.scroll
			var bar: VScrollBar = scroll.get_v_scroll_bar()
			if not bar.is_visible_in_tree():
				continue
			scrolled += 1
			var edge: float = (
				bar.get_global_rect().position.x - ProseScroll.BAR_GAP + ClipCheck.SLACK
			)
			for label: Label in scroll.find_children("*", "Label", true, false):
				var rect: Rect2 = label.get_global_rect()
				if label.is_visible_in_tree() and rect.end.x > edge:
					var where: String = "size %d on %s" % [level, screen]
					problems.append(
						(
							"%s: %s ends at %.0f, bar at %.0f"
							% [where, label.text.left(20), rect.end.x, edge + ProseScroll.BAR_GAP]
						)
					)
	assert_int(scrolled).is_greater(0)
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()
