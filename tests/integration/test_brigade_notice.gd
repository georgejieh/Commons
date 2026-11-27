extends GdUnitTestSuite
## The brigade notice on the table's wall at every text size (ADR 0034): its paper grows
## upward from where it hangs at Standard, its bottom and left edges and its width kept,
## so its words stay on it and clear of the status line under it and the Campaign tray
## above; the redaction bars each lie over one of the first lines of its text. ClipCheck
## does not see this: nothing clips, the notice only grew into the status line's room.

const SEED: int = 4301
const SCREEN: Vector2i = Vector2i(1920, 1080)

var _app: App
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	get_tree().root.size = SCREEN
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)
	_app.new_run(SEED)


func after_test() -> void:
	Settings.set_value(TextSize.SETTING, 0)
	get_tree().root.size = _was_size
	Saves.run_service().delete()


func _table_at(level: int) -> TableScreen:
	Settings.set_value(TextSize.SETTING, level)
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	await await_idle_frame()
	return table


func test_the_notice_grows_upward_and_keeps_clear_at_every_size() -> void:
	for level: int in TextSize.count():
		var table: TableScreen = await _table_at(level)
		var dressing: DreadDressing = table.dressing
		var notice: Rect2 = dressing.notice_rect()
		var at: String = "size %d: %s" % [level, notice]
		assert_float(notice.end.y).override_failure_message(at).is_equal(
			DreadDressing.NOTICE_AT.end.y
		)
		assert_float(notice.position.x).override_failure_message(at).is_equal(
			DreadDressing.NOTICE_AT.position.x
		)
		assert_float(notice.size.x).override_failure_message(at).is_equal(
			DreadDressing.NOTICE_AT.size.x
		)
		if level == 0:
			assert_bool(notice.is_equal_approx(DreadDressing.NOTICE_AT)).is_true()
		var words: Rect2 = dressing.notice_words().get_global_rect()
		assert_bool(notice.encloses(words)).override_failure_message(at).is_true()
		var status: Label = table.you
		(
			assert_bool(notice.intersects(status.get_global_rect()))
			. override_failure_message(at)
			. is_false()
		)
		var campaigns: TableCampaigns = table.campaigns
		var tray: CampaignTray = campaigns.tray
		if tray.is_visible_in_tree() and tray.get_global_rect().has_area():
			(
				assert_bool(notice.intersects(tray.get_global_rect()))
				. override_failure_message(at)
				. is_false()
			)


func test_each_redaction_bar_lies_over_a_line_of_the_notice() -> void:
	for level: int in TextSize.count():
		for shown: bool in [false, true]:
			var table: TableScreen = await _table_at(level)
			var dressing: DreadDressing = table.dressing
			# The dread layers drive the bars' weight each update; the bars' place is the
			# same either way.
			dressing.show_piece("redaction", 1.0 if shown else 0.0)
			await await_idle_frame()
			var words: Label = dressing.notice_words()
			var top: float = words.get_global_rect().position.y
			var line_tall: float = words.get_line_height()
			var pitch: float = line_tall + words.get_theme_constant("line_spacing")
			var bars: Array[Rect2] = dressing.redaction_rects()
			assert_int(bars.size()).is_equal(DreadDressing.REDACTION_LINES)
			assert_int(words.get_line_count()).is_greater_equal(bars.size())
			for line: int in bars.size():
				var band: Rect2 = Rect2(
					words.get_global_rect().position.x, top + line * pitch, 1.0, line_tall
				)
				var bar: Rect2 = bars[line]
				var at: String = "size %d line %d: %s over %s" % [level, line, bar, band]
				var inside: bool = (
					bar.position.y >= band.position.y - 0.5 and bar.end.y <= band.end.y + 0.5
				)
				assert_bool(inside).override_failure_message(at).is_true()
				(
					assert_bool(dressing.notice_rect().encloses(bar))
					. override_failure_message(at)
					. is_true()
				)


## The wall changes: a different notice from one deal to the next, from another set in the
## middle Years and another in the last, each a real string, and none standing taller
## than the first, so nothing laid out round the notice moves when it changes.
func test_the_notice_changes_with_the_deal_and_the_years() -> void:
	var seen: Dictionary[String, bool] = {}
	for year: int in [1, 2, 3, 5, 6, 8]:
		for turn: int in DreadDressing.NOTICES:
			var key: String = DreadDressing.notice_key(year, turn)
			assert_str(tr(key)).override_failure_message(key).is_not_equal(key)
			seen[key] = true
	assert_int(seen.size()).is_equal(DreadDressing.NOTICES * 3)
	assert_str(DreadDressing.notice_key(1, 0)).is_not_equal(DreadDressing.notice_key(1, 1))
	assert_str(DreadDressing.notice_key(2, 5)).is_equal(DreadDressing.notice_key(1, 1))
	assert_str(DreadDressing.notice_key(3, 0)).contains(".mid.")
	assert_str(DreadDressing.notice_key(6, 0)).contains(".late.")
	for level: int in TextSize.count():
		var table: TableScreen = await _table_at(level)
		var dressing: DreadDressing = table.dressing
		var first: float = dressing.notice_rect().size.y
		for key: String in seen:
			dressing.post_notice(key)
			await await_idle_frame()
			await await_idle_frame()
			assert_str(dressing.notice_text()).is_equal(tr(key))
			var where: String = "%s at size %d" % [key, level]
			var tall: float = dressing.notice_rect().size.y
			assert_float(tall).override_failure_message(where).is_less_equal(first + 0.5)


## The score tally keeps clear of the notice on its left and of the action column on its
## right for an ordinary play; a sum of very wide numbers may lie over the notice, which
## is dressing, and still never over the column.
func test_the_tally_keeps_clear_of_the_notice_and_the_buttons() -> void:
	Settings.set_value("reduced_motion", true)
	var table: TableScreen = await _table_at(0)
	var dressing: DreadDressing = table.dressing
	var moments: TableMoments = table.moments
	for wide: bool in [false, true]:
		var scored: RunEvent = RunEvent.new(
			RunEvent.Type.PLAY_SCORED, 0, 0, 999999.0 if wide else 567.0
		)
		scored.grain = 9999.0 if wide else 54.0
		scored.rate = 96.0 if wide else 7.0
		scored.zeal = 12.5 if wide else 1.5
		moments.sequence.play(scored, 0.0)
		await await_idle_frame()
		await await_idle_frame()
		var tally: Rect2 = moments.tally.get_global_rect()
		assert_bool(tally.has_area()).is_true()
		assert_bool(tally.intersects(table.actions.get_global_rect())).is_false()
		if not wide:
			assert_bool(tally.intersects(dressing.notice_rect())).is_false()
	Settings.set_value("reduced_motion", false)
