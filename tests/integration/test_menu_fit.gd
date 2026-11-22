extends GdUnitTestSuite
## The menus stand whole at every text size at 1920x1080 and 1280x800 (P5.2a): the
## settings sheets fit the page with nothing out of sight, the Controls rows stop at a
## whole row with the fade over the cut, no title button lies on a face in the poster,
## the dialogs over the notice wall cover its blank board, the set summary's seals stay
## on the paper and off each other, and a dialog's words keep clear of its printed rule.

const SEED: int = 5303
const SAVE_PATH: String = "user://test_menu_fit/run.json"
const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 800)]
const SLACK: float = 1.5
## How far a dialog sheet may leave its board uncovered at an edge, the board's own frame.
const BOARD_SLACK: float = 30.0

var _app: DemoApp
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	Settings.set_value("reduced_motion", true)
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	Saves.profile_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)


func after_test() -> void:
	Settings.set_value(TextSize.SETTING, 0)
	Settings.set_value("reduced_motion", false)
	get_tree().root.size = _was_size
	Saves.run_service().delete()
	Saves.profile_service().delete()


func _show(screen_id: String) -> Control:
	var shown: Control = _app.show_screen(screen_id, true)
	await await_idle_frame()
	await await_idle_frame()
	return shown


## Every size at every window, as "level size".
func _each() -> Array[Array]:
	var made: Array[Array] = []
	for level: int in TextSize.count():
		for screen_size: Vector2i in SIZES:
			made.append([level, screen_size])
	return made


func _at(pair: Array) -> String:
	Settings.set_value(TextSize.SETTING, int(pair[0]))
	get_tree().root.size = pair[1]
	return "text size %d at %s" % [pair[0], pair[1]]


func test_the_settings_sheets_stand_whole_at_every_size() -> void:
	for pair: Array in _each():
		var where: String = _at(pair)
		var screen: SettingsScreen = await _show("settings")
		var view: Rect2 = screen.scroll().get_global_rect().grow(SLACK)
		for sheet: Control in screen.sheets():
			var rect: Rect2 = sheet.get_global_rect()
			(
				assert_bool(view.encloses(rect))
				. override_failure_message("%s %s" % [where, rect])
				. is_true()
			)
		var fade: ScrollFade = screen.scroll().find_child("ScrollFade", false, false)
		assert_object(fade).override_failure_message(where).is_not_null()
		assert_bool(fade.more_below()).override_failure_message(where).is_false()
		var problems: PackedStringArray = []
		ClipCheck.check(screen, where, problems)
		assert_array(problems).override_failure_message("\n".join(problems)).is_empty()


## At the table the line saying when a new size arrives stands under the size boxes, in
## line with them, before the toggles.
func test_the_tables_text_size_line_stands_under_its_boxes() -> void:
	_app.new_run(SEED)
	for pair: Array in _each():
		var where: String = _at(pair)
		var table: TableScreen = await _show("table")
		table.call("_open_pause")
		var pause: PauseMenu = table.get("_pause")
		pause.call("_show_page", pause.get("_settings"))
		await await_idle_frame()
		var note: Label = _labelled(pause, tr("settings.text_size.table"))
		var standard: Control = pause.find_child(SettingsPanel.TEXT_SIZE_BOX % 0, true, false)
		var largest: Control = pause.find_child(SettingsPanel.TEXT_SIZE_BOX % 2, true, false)
		var motion: Control = _labelled_button(pause, tr("settings.reduced_motion"))
		var line: Rect2 = note.get_global_rect()
		assert_float(line.position.x).override_failure_message(where).is_greater_equal(
			standard.get_global_rect().position.x - SLACK
		)
		assert_float(line.position.y).override_failure_message(where).is_greater_equal(
			largest.get_global_rect().end.y - SLACK
		)
		assert_float(line.end.y).override_failure_message(where).is_less_equal(
			motion.get_global_rect().position.y + SLACK
		)
		pause.visible = false


## The rows stop at the foot of a whole row: every key's ticket is whole inside the
## scroll or wholly past its cut, and the fade lies over the cut while more lies below.
func test_the_controls_rows_stop_at_a_whole_row() -> void:
	for pair: Array in _each():
		var where: String = _at(pair)
		var screen: ControlsScreen = await _show("controls")
		var page: ControlsPage = screen.page()
		var rows: ProseScroll = page.rows_scroll()
		var view: Rect2 = rows.get_global_rect().grow(SLACK)
		for action: String in KeyBindings.ACTIONS:
			var rect: Rect2 = page.ticket(action).get_global_rect()
			var whole: bool = view.encloses(rect) or rect.position.y >= view.end.y - SLACK
			(
				assert_bool(whole)
				. override_failure_message("%s %s %s" % [where, action, rect])
				. is_true()
			)
		var fade: ScrollFade = rows.find_child("ScrollFade", false, false)
		assert_bool(fade.more_below()).is_equal(rows.can_scroll())
		# The bar stands beside the keys, not at the far side of the page.
		assert_float(page.size.x).override_failure_message(where).is_less(1000.0)


## With a saved run, Continue stands beside New Run, and no title button lies on a face
## in the poster at either window or any text size.
func test_no_title_button_lies_on_a_face() -> void:
	_app.new_run(SEED)
	for pair: Array in _each():
		var where: String = _at(pair)
		var title: TitleScreen = await _show("title")
		var poster: TextureRect = title.poster() as TextureRect
		var faces: Array[Rect2] = []
		for face: Rect2 in TitleScreen.FACES:
			faces.append(_on_cover(poster, face))
		var continued: bool = false
		for node: Node in title.find_children("*", "Button", true, false):
			var button: Button = node as Button
			continued = continued or button.text == tr("title.continue")
			for face: Rect2 in faces:
				var at: String = "%s: %s on %s" % [where, button.text, face]
				(
					assert_bool(button.get_global_rect().intersects(face))
					. override_failure_message(at)
					. is_false()
				)
		assert_bool(continued).override_failure_message(where).is_true()


## The verdicts and records over the notice wall cover its blank board.
func test_the_notice_wall_dialogs_cover_the_board() -> void:
	_app.new_run(SEED)
	for pair: Array in _each():
		var where: String = _at(pair)
		for screen_id: String in ["set_summary", "dossier", "round_summary"]:
			var screen: Control = await _show(screen_id)
			var art: TextureRect = screen.get_child(0) as TextureRect
			var board: Rect2 = _on_cover(art, SheetPad.BOARD)
			board = board.intersection(get_tree().root.get_visible_rect()).grow(-BOARD_SLACK)
			var sheet: Control = _sheet_of(screen)
			var at: String = "%s %s: %s over %s" % [where, screen_id, _drawn(sheet), board]
			assert_bool(_drawn(sheet).encloses(board)).override_failure_message(at).is_true()
			_check_padding(sheet, "%s %s" % [where, screen_id])


## The overfulfilled seal stands clear of the met seal, and both on the paper.
func test_the_set_summarys_seals_stay_on_the_paper() -> void:
	_app.new_run(SEED)
	for pair: Array in _each():
		var where: String = _at(pair)
		var screen: SetSummaryScreen = await _show("set_summary")
		var met: InkSeal = screen.bar().get("_seal")
		var over: InkSeal = screen.over_seal()
		var paper: Rect2 = _drawn(_sheet_of(screen)).grow(-SheetPad.RULE)
		var over_rect: Rect2 = over.get_global_rect().grow(over.size.x * 0.05)
		var met_rect: Rect2 = met.get_global_rect().grow(met.size.x * 0.05)
		assert_bool(over_rect.intersects(met_rect)).override_failure_message(where).is_false()
		for rect: Rect2 in [over_rect, met_rect]:
			(
				assert_bool(paper.encloses(rect))
				. override_failure_message("%s %s in %s" % [where, rect, paper])
				. is_true()
			)


## The pause menu, its question and the year's end keep their words clear of the rule,
## and the question has a title of its own.
func test_the_dialogs_keep_their_padding() -> void:
	_app.new_run(SEED)
	for pair: Array in _each():
		var where: String = _at(pair)
		var table: TableScreen = await _show("table")
		table.call("_open_pause")
		var pause: PauseMenu = table.get("_pause")
		await await_idle_frame()
		_check_padding(_sheet_of(pause.get("_main")), where + " menu")
		pause.call("_show_page", pause.get("_confirm"))
		await await_idle_frame()
		var confirm: Control = _sheet_of(pause.get("_confirm"))
		_check_padding(confirm, where + " question")
		assert_object(_labelled(confirm, tr("menu.abandon"))).is_not_null()
		pause.visible = false
		var year: Control = await _show("year_summary")
		_check_padding(_sheet_of(year), where + " year")


## No word or button on a padded sheet comes closer to its edge than its padding.
func _check_padding(sheet: Control, where: String) -> void:
	var inside: Rect2 = sheet.get_global_rect().grow(-SheetPad.INSET + SLACK)
	for node: Node in sheet.find_children("*", "Control", true, false):
		var control: Control = node as Control
		var prints: bool = control is Label or control is Button
		if not prints or not control.is_visible_in_tree() or control.get_parent() is InkSeal:
			continue
		var rect: Rect2 = control.get_global_rect()
		(
			assert_bool(inside.encloses(rect))
			. override_failure_message(
				"%s: %s at %s, inside %s" % [where, control.get_path(), rect, inside]
			)
			. is_true()
		)


## The first panel drawn with the dialog padding under root.
func _sheet_of(root: Node) -> PanelContainer:
	for node: Node in root.find_children("*", "PanelContainer", true, false):
		var panel: PanelContainer = node as PanelContainer
		var style: StyleBox = panel.get_theme_stylebox("panel")
		if style != null and style.content_margin_left == SheetPad.INSET:
			return panel
	return null


## A rect given as shares of a covering picture, where it lies on the screen.
func _on_cover(art: TextureRect, share: Rect2) -> Rect2:
	var picture: Vector2 = art.texture.get_size()
	var shown: Rect2 = art.get_global_rect()
	var scale: float = maxf(shown.size.x / picture.x, shown.size.y / picture.y)
	var corner: Vector2 = shown.position + (shown.size - picture * scale) / 2.0
	return Rect2(corner + share.position * picture * scale, share.size * picture * scale)


func _drawn(control: Control) -> Rect2:
	var shown: Transform2D = control.get_global_transform()
	return Rect2(shown.origin, control.size * shown.get_scale())


func _labelled(root: Node, text: String) -> Label:
	for node: Node in root.find_children("*", "Label", true, false):
		if (node as Label).text == text and (node as Label).is_visible_in_tree():
			return node as Label
	return null


func _labelled_button(root: Node, text: String) -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		if (node as Button).text == text and (node as Button).is_visible_in_tree():
			return node as Button
	return null


## The collection's scroll is as wide as its whole cards, so its bar stands beside them,
## and it fades at the cut while more lies below.
func test_the_collections_bar_stands_beside_its_cards() -> void:
	for pair: Array in _each():
		var where: String = _at(pair)
		var screen: CollectionScreen = await _show("collection")
		var scroll: ScrollContainer = screen.scroll()
		var right: float = 0.0
		for entry: Control in screen.entries():
			right = maxf(right, entry.get_global_rect().end.x)
		var bar: VScrollBar = scroll.get_v_scroll_bar()
		var gap: float = bar.get_global_rect().position.x - right
		assert_float(gap).override_failure_message("%s gap %.0f" % [where, gap]).is_between(
			0.0, CollectionScreen.BAR_ROOM + SLACK
		)
		var fade: ScrollFade = scroll.find_child("ScrollFade", false, false)
		assert_bool(fade.more_below()).override_failure_message(where).is_true()
