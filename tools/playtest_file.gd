extends RefCounted
## The playtest's frames of the family's file (ADR 0022), in sandboxes put back after, as
## the playtest's wild-rank and debuff frames are. A development build never acts on a
## changed figure, so every frame here is set up by hand: at the table the state's notice
## is shown from BOOKS_CORRECTED events built here and sent as the controller sends them
## (a raised coupon figure, a lowered meter, a broken seal), each acknowledged with a key
## press; then the HUD with a dark meter and a dark norm, and the table at the stage past
## the last with the small ledger. In the shops, the black market with raised prices and a
## dark Resentment, then both shops at the stage past the last. From a profile handed two
## entries, the title's stamp at stages 0, 4 and 9 and the history's page of the file. The
## run's figures are never touched, so the second book has nothing to find, and the
## profile is put back by the playtest after. Loaded at run time by playtest.gd, so it
## reaches every UI node as Object, Node or Control, never by a ui/ class name.
## Development only; tools/ never ships.

const SETTLE_SECONDS: float = 1.2
const WAIT_SECONDS: float = 20.0
const STAMP_STAGES: Array[int] = [0, 4, 9]
## The raised coupon figure and the lowered meter the notices are shown for.
const COUPONS: Vector2i = Vector2i(12, 120)
const FAMINE: Vector2i = Vector2i(40, 5)
const RAISE: int = 900
## What the shop sandbox raises prices by.
const PRICE_PERCENT: int = 50

var shots: int = 0
var misclicks: int = 0

var _tree: SceneTree
var _app: Node
var _out: String
var _headless: bool


func _init(tree: SceneTree, app: Node, out: String, headless: bool, shot_count: int) -> void:
	_tree = tree
	_app = app
	_out = out
	_headless = headless
	shots = shot_count


## The table's frames, from the round under way, put back as they were after.
func table() -> void:
	var controller: Object = _app.get("controller")
	var loop: RunLoop = controller.get("_loop")
	var snapshot: Dictionary = loop.record.to_dict()
	var was: int = ArtStages.stage_override
	_app.call("show_screen", "table", true)
	await _frames(20)
	await _until(_idle)
	await _notice("file_notice_coupons", _raised_coupons())
	await _notice("file_notice_meter", _lowered_meter())
	await _notice("file_notice_seal", BooksCorrection.new())
	loop.state.books.dark.assign([RunCorrections.FAMINE, RunCorrections.NORM])
	controller.call("reseal_book")
	_app.call("show_screen", "table", true)
	await _frames(20)
	await _until(_idle)
	var hud: Object = _part("_hud")
	var quota: Object = hud.get("quota")
	_expect(not bool(hud.call("shows_meter", "famine")), "DARK FAMINE STILL SHOWN")
	_expect(str(quota.call("text")).contains(_none()), "DARK NORM SHOWS THE TARGET")
	await _shot("file_table_dark")
	loop.state.books.dark.clear()
	ArtStages.stage_override = ArtStages.FILED_STAGE
	_app.call("show_screen", "table", true)
	await _frames(20)
	await _until(_idle)
	var ledger: Object = _part("_ledger")
	var books: Control = ledger.get("books")
	_expect(books.is_visible_in_tree(), "NO SMALL LEDGER AT THE TABLE")
	await _shot("file_table_stage_10")
	ArtStages.stage_override = was
	var saves: Object = _tree.root.get_node("Saves").call("run_service")
	saves.call("save", snapshot, ContentStamp.extras())
	_app.call("resume_to_screen")
	await _frames(30)


## The black market with raised prices and a dark Resentment, then both shops at the
## stage past the last, from the state store, which is left as it was found.
func store() -> void:
	var controller: Object = _app.get("controller")
	var loop: RunLoop = controller.get("_loop")
	var books: RunBooks = loop.state.books
	var was_dark: Array[String] = books.dark.duplicate()
	var was_price: int = books.price_percent
	var was: int = ArtStages.stage_override
	books.price_percent = PRICE_PERCENT
	books.dark.assign([RunCorrections.RESENTMENT])
	controller.call("reseal_book")
	_app.call("show_screen", "black_market")
	await _frames(30)
	var market: Node = _current()
	var count: Label = market.get("_resentment")
	_expect(count.text == _none(), "DARK RESENTMENT SHOWN AS %s" % count.text)
	await _shot("file_shop_dark")
	books.dark.assign(was_dark)
	books.price_percent = was_price
	ArtStages.stage_override = ArtStages.FILED_STAGE
	market.call("_refresh")
	await _frames(10)
	var market_books: Control = market.get("_books")
	_expect(market_books.is_visible_in_tree(), "NO SMALL LEDGER IN MARKET")
	await _shot("file_market_stage_10")
	_app.call("back")
	await _frames(30)
	var shop: Node = _current()
	var shop_books: Control = shop.get("_books")
	_expect(shop_books.is_visible_in_tree(), "NO SMALL LEDGER IN STORE")
	await _shot("file_store_stage_10")
	ArtStages.stage_override = was
	controller.call("reseal_book")
	_app.call("show_screen", "store", true)
	await _frames(30)


## The title's stamp at three stages and the history's page, for a profile handed two
## entries. The playtest puts the profile's files back after.
func meta(profile: SaveService) -> void:
	var data: ProfileData = ProfileData.new()
	data.file.append(_entry(FileEntry.BOOK, 2, 3, 7, {"coupons": 120.0, "famine": 5.0}))
	data.file.append(_entry(FileEntry.SEAL, 3, 1, 0, {}))
	Profile.write(profile, data)
	var was: int = ArtStages.stage_override
	for stage: int in STAMP_STAGES:
		ArtStages.stage_override = stage
		_app.call("show_screen", "title", true)
		await _frames(20)
		_check_stamp(_current())
		await _shot("file_title_stage_%d" % stage)
	ArtStages.stage_override = was
	_app.call("show_screen", "village_history")
	await _frames(30)
	var page: Node = _current()
	var lines: PackedStringArray = page.call("file_lines")
	_expect(lines.size() == data.file.size() + 1, "FILE PAGE HOLDS %d LINES" % lines.size())
	await _shot("file_history")
	_app.call("back")
	await _frames(20)


## The stamp is on the title, clear of every button and of the title itself.
func _check_stamp(title: Node) -> void:
	var stamp: Control = title.call("stamp")
	if stamp == null:
		_fail("NO STAMP ON THE TITLE")
		return
	var area: Rect2 = stamp.get_global_rect()
	for found: Node in title.find_children("*", "Control", true, false):
		var control: Control = found as Control
		if control == stamp or not control.is_visible_in_tree():
			continue
		if control is Button or (control is Label and (control as Label).text == tr("game.title")):
			_expect(
				not area.intersects(control.get_global_rect()), "STAMP COVERS %s" % control.name
			)


## One notice on the table: sent as the controller sends a live event, photographed,
## acknowledged with the accept key, and the table's queue let go again.
func _notice(name: String, correction: BooksCorrection) -> void:
	var controller: Object = _app.get("controller")
	var notice: Object = _app.get("notice")
	var event: RunEvent = RunEvent.new(RunEvent.Type.BOOKS_CORRECTED, 0, 1)
	event.correction = correction
	controller.emit_signal("event_emitted", event)
	await _frames(10)
	_expect(bool(notice.call("is_showing")), "NO NOTICE FOR %s" % name)
	var events: Node = _part("_player")
	_expect(events != null and not events.is_processing(), "TABLE NOT HELD BY %s" % name)
	await _shot(name)
	for pressed: bool in [true, false]:
		var key: InputEventKey = InputEventKey.new()
		key.keycode = KEY_ENTER
		key.physical_keycode = KEY_ENTER
		key.pressed = pressed
		_tree.root.push_input(key, true)
		await _frames(2)
	_expect(not bool(notice.call("is_showing")), "NOTICE %s NOT ACKNOWLEDGED" % name)
	_expect(events != null and events.is_processing(), "TABLE STILL HELD AFTER %s" % name)


func _raised_coupons() -> BooksCorrection:
	var correction: BooksCorrection = BooksCorrection.new()
	correction.add(RunCorrections.COUPONS, COUPONS.x, COUPONS.y)
	correction.norm_added = RAISE
	correction.price_added = RAISE
	return correction


func _lowered_meter() -> BooksCorrection:
	var correction: BooksCorrection = BooksCorrection.new()
	correction.add(RunCorrections.FAMINE, FAMINE.x, FAMINE.y)
	correction.dark.append(RunCorrections.FAMINE)
	return correction


static func _entry(
	detector: String, generation: int, year: int, quota: int, figures: Dictionary
) -> FileEntry:
	var entry: FileEntry = FileEntry.new()
	entry.detector = detector
	entry.run_id = "playtest-file-%d" % generation
	entry.generation = generation
	entry.year = year
	entry.quota = quota
	for figure: String in figures:
		entry.figures[figure] = float(figures[figure])
	entry.key = "playtest:%s:%d" % [detector, generation]
	return entry


func _none() -> String:
	return tr("figure.none_reported")


func _current() -> Node:
	var switcher: Object = _app.get("switcher")
	return switcher.call("current")


func _idle() -> bool:
	var events: Object = _part("_player")
	return events == null or bool(events.call("is_idle"))


## A part of the table now on screen, by its property name, or null off it.
func _part(part: String) -> Object:
	var screen: Node = _current()
	if screen == null or not is_instance_valid(screen) or screen.get("_player") == null:
		return null
	return screen.get(part)


func _until(ready: Callable, seconds: float = WAIT_SECONDS) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while not bool(ready.call()):
		if Time.get_ticks_msec() > deadline:
			return false
		await _frames(1)
	return true


func _expect(held: bool, failure: String) -> void:
	if not held:
		_fail(failure)


func _fail(reason: String) -> void:
	print("MISS %s" % reason)
	misclicks += 1


func _frames(count: int) -> void:
	for _frame: int in count:
		await _tree.process_frame


func _shot(name: String) -> void:
	await _tree.create_timer(SETTLE_SECONDS).timeout
	shots += 1
	if _headless:
		print("FRAME %02d_%s" % [shots, name])
		return
	await RenderingServer.frame_post_draw
	var path: String = _out.path_join("%02d_%s.png" % [shots, name])
	_tree.root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
