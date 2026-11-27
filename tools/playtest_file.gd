extends WalkBase
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
## profile is put back by the playtest after. Development only; tools/ never ships.

const STAMP_STAGES: Array[int] = [0, 4, 9]
## The raised coupon figure and the lowered meter the notices are shown for.
const COUPONS: Vector2i = Vector2i(12, 120)
const FAMINE: Vector2i = Vector2i(40, 5)
const RAISE: int = 900
## What the shop sandbox raises prices by.
const PRICE_PERCENT: int = 50


## The table's frames, from the round under way, put back as they were after.
func table() -> void:
	var controller: Object = _controller()
	var loop: RunLoop = _loop()
	var snapshot: Dictionary = loop.record.to_dict()
	var was: int = ArtStages.stage_override
	app.call("show_screen", ScreenId.TABLE, true)
	await _frames(20)
	await _until(_idle)
	await _notice("file_notice_coupons", _raised_coupons())
	await _notice("file_notice_meter", _lowered_meter())
	await _notice("file_notice_seal", BooksCorrection.new())
	loop.state.books.dark.assign([RunCorrections.FAMINE, RunCorrections.NORM])
	controller.call("reseal_book")
	app.call("show_screen", ScreenId.TABLE, true)
	await _frames(20)
	await _until(_idle)
	var hud: Object = _part("hud")
	var quota: Object = hud.get("quota")
	_expect(not bool(hud.call("shows_meter", "famine")), "DARK FAMINE STILL SHOWN")
	_expect(str(quota.call("text")).contains(_none()), "DARK NORM SHOWS THE TARGET")
	await _shot("file_table_dark")
	loop.state.books.dark.clear()
	ArtStages.stage_override = ArtStages.FILED_STAGE
	app.call("show_screen", ScreenId.TABLE, true)
	await _frames(20)
	await _until(_idle)
	var ledger: Object = _part("ledger")
	var books: Control = ledger.get("books")
	_expect(books.is_visible_in_tree(), "NO SMALL LEDGER AT THE TABLE")
	await _shot("file_table_stage_10")
	ArtStages.stage_override = was
	await _restore(snapshot)


## The black market with raised prices and a dark Resentment, then both shops at the
## stage past the last, from the state store, which is left as it was found.
func store() -> void:
	var controller: Object = _controller()
	var loop: RunLoop = _loop()
	var books: RunBooks = loop.state.books
	var was_dark: Array[String] = books.dark.duplicate()
	var was_price: int = books.price_percent
	var was: int = ArtStages.stage_override
	books.price_percent = PRICE_PERCENT
	books.dark.assign([RunCorrections.RESENTMENT])
	controller.call("reseal_book")
	app.call("show_screen", ScreenId.BLACK_MARKET)
	await _frames(30)
	var market: Node = _current()
	var count: Label = member(market, "resentment")
	_expect(count.text == _none(), "DARK RESENTMENT SHOWN AS %s" % count.text)
	await _shot("file_shop_dark")
	books.dark.assign(was_dark)
	books.price_percent = was_price
	ArtStages.stage_override = ArtStages.FILED_STAGE
	invoke(market, "refresh")
	await _frames(10)
	var market_books: Control = member(market, "books")
	_expect(market_books.is_visible_in_tree(), "NO SMALL LEDGER IN MARKET")
	await _shot("file_market_stage_10")
	app.call("back")
	await _frames(30)
	var shop: Node = _current()
	var shop_books: Control = member(shop, "books")
	_expect(shop_books.is_visible_in_tree(), "NO SMALL LEDGER IN STORE")
	await _shot("file_store_stage_10")
	ArtStages.stage_override = was
	controller.call("reseal_book")
	app.call("show_screen", ScreenId.STORE, true)
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
		app.call("show_screen", ScreenId.TITLE, true)
		await _frames(20)
		_check_stamp(_current())
		await _shot("file_title_stage_%d" % stage)
	ArtStages.stage_override = was
	app.call("show_screen", ScreenId.VILLAGE_HISTORY)
	await _frames(30)
	var page: Node = _current()
	var lines: PackedStringArray = page.call("file_lines")
	_expect(lines.size() == data.file.size() + 1, "FILE PAGE HOLDS %d LINES" % lines.size())
	await _shot("file_history")
	app.call("back")
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
		if control is Button or control is TitleWord:
			_expect(
				not area.intersects(control.get_global_rect()), "STAMP COVERS %s" % control.name
			)


## One notice on the table: sent as the controller sends a live event, photographed,
## acknowledged with the accept key, and the table's queue let go again.
func _notice(name: String, correction: BooksCorrection) -> void:
	var controller: Object = app.get("controller")
	var notice: Object = app.get("notice")
	var event: RunEvent = RunEvent.new(RunEvent.Type.BOOKS_CORRECTED, 0, 1)
	event.correction = correction
	controller.emit_signal("event_emitted", event)
	await _frames(10)
	_expect(bool(notice.call("is_showing")), "NO NOTICE FOR %s" % name)
	var events: Node = _part("player")
	_expect(events != null and not events.is_processing(), "TABLE NOT HELD BY %s" % name)
	await _shot(name)
	await _press_key(KEY_ENTER)
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
