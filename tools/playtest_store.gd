extends WalkBase
## The playtest's visit to the shops (tools/playtest_demo.gd walks there): the state
## store's marks, file and wild-rank frames, a Cadre bought, a Directive issued, the
## Campaign, Reform and envelope bought and photographed, a keyword's slip found with the
## pointer, then the black market (tools/playtest_market.gd).
## What a frame needs that the run did not deal, coupons, stock and Cadres, is handed over
## through the run's state and its record, so the run still replays, or staged in a
## sandbox and put back. Each part is taken once a run. Development only; tools/ never
## ships.

const Marks := preload("res://tools/playtest_marks.gd")
const FileWalk := preload("res://tools/playtest_file.gd")
const Wild := preload("res://tools/playtest_wild.gd")
const Market := preload("res://tools/playtest_market.gd")

## True once the state store's Campaign was bought, for the table's Campaign turn.
var campaign_bought: bool = false
## True once the deck exchange was made at the state store, for the table's deck frame.
var exchanged: bool = false

var _marks_shot: bool = false
var _file_shot: bool = false
var _wild_shot: bool = false
var _scarce_shot: bool = false
var _issued: bool = false
var _reform_shot: bool = false
var _keyword_shot: bool = false
var _envelope_shot: bool = false
## How many marked words the pointer has come to rest on, for a failure's report.
var _words_rested: int = 0


## The whole visit, from the state store to leaving it: marks, file, wild_ranks and market
## are the walks of those frames.
func visit(marks: Marks, file: FileWalk, wild_ranks: Wild, market: Market) -> void:
	await _shot("store")
	if not _marks_shot:
		_marks_shot = true
		await marks.store()
		exchanged = marks.exchanged
	if not _file_shot:
		_file_shot = true
		await file.store()
	if not _wild_shot:
		_wild_shot = true
		await wild_ranks.store()
		await wild_ranks.scarce(false)
	await _reform_frames()
	await _buy_one()
	await _issue_one()
	await _buy_campaign()
	await _keyword_frames()
	await _envelope_frames()
	await _click_button_with_text(tr("market.open"))
	await _shot("black_market")
	if not _scarce_shot:
		_scarce_shot = true
		await wild_ranks.scarce(true)
	await market.parcel()
	# The Parcel's sandbox resumes the saved run, which lands in the state store.
	if _screen_id() != "black_market":
		await _click_button_with_text(tr("market.open"))
	await market.counter()
	await _click_button_with_text(tr("market.back"))
	await _click_button_with_text(tr("store.leave"))


## Buys the first Cadre the store will sell, and photographs the store after.
func _buy_one() -> void:
	var screen: Node = _current()
	for child: Node in screen.find_children("*", "Button", true, false):
		var button: Button = child as Button
		if button.theme_type_variation == "CouponButton" and not button.disabled:
			# The seal as it lands on a card, pressed by hand so it can be photographed.
			var seal: Control = member(screen, "_seal")
			var counter: Control = member(screen, "_counter")
			var card: Control = counter.get_child(0)
			seal.position = card.global_position + card.size / 2.0 - seal.size / 2.0
			seal.call("press")
			await _snap("store_seal")
			seal.hide()
			await _press(button)
			for frame: int in 3:
				await _snap("store_buying_%d" % frame)
			await _frames(30)
			await _shot("store_bought")
			return


## Photographs the Directive column, then issues the first Directive the coupons allow and
## photographs the seal, the Rates ticking and the document leaving.
func _issue_one() -> void:
	if _issued:
		return
	var row: Control = member(_current(), "_directives")
	if row == null or row.get_child_count() < 2:
		return
	_issued = true
	await _shot("store_directives")
	for child: Node in row.find_children("*", "Button", true, false):
		var button: Button = child as Button
		if button.theme_type_variation == "CouponButton" and not button.disabled:
			await _press(button)
			for frame: int in 5:
				await _snap("store_issuing_%d" % frame)
			await _frames(30)
			await _shot("store_issued")
			return


## Buys the state store's Campaign and photographs its offer with the slip that explains
## it, then its leaflet flying into the tray on the board.
func _buy_campaign() -> void:
	if campaign_bought:
		return
	var screen: Node = _current()
	var stall: Object = member(screen, "_campaign_stall")
	if stall.call("panel", 0) == null:
		return
	_grant_coupons(12)
	invoke(screen, "_refresh")
	await _frames(10)
	var offer: Control = stall.call("panel", 0)
	var buy: Button = offer.get("buy")
	if buy == null or not buy.visible or buy.disabled:
		return
	await _hover(offer)
	await _shot("store_campaign_offer")
	await _press(buy)
	for frame: int in 3:
		await _snap("store_campaign_buying_%d" % frame)
	await _frames(30)
	campaign_bought = true
	await _shot("store_campaign_tray")


## The state store's Reform: its decree on the counter with the slip, the "Enacted" stamp
## and its flight, the strip it is pinned to and a pinned slip read out by focus.
func _reform_frames() -> void:
	if _reform_shot:
		return
	var screen: Node = _current()
	var stall: Object = member(screen, "_reform_stall")
	if stall == null or stall.call("panel", 0) == null:
		return
	_reform_shot = true
	_grant_coupons(12)
	invoke(screen, "_refresh")
	await _frames(10)
	var offer: Control = stall.call("panel", 0)
	await _hover(offer)
	await _shot("store_reform_offer")
	await _press(offer.get("buy"))
	for frame: int in 4:
		await _snap("store_reform_enacting_%d" % frame)
	# On the clock: the stamp and the flight take longer than a fast frame count.
	await tree.create_timer(1.2).timeout
	await _shot("store_reform_strip")
	var strip: Object = stall.get("strip")
	if int(strip.call("held_count")) > 0:
		var pinned: Control = strip.call("tag", 0)
		pinned.grab_focus()
		await _snap("store_reform_strip_slip")


## A keyword's slip with the real pointer: it is swept over the store's rules text until
## it rests on a keyword, the slip that opens is photographed, and the pointer then moves
## onto the slip, which must still be there a second later.
func _keyword_frames() -> void:
	if _keyword_shot:
		return
	_keyword_shot = true
	var tips: Object = null
	var marked: int = 0
	for found: Node in _current().find_children("*", "RichTextLabel", true, false):
		var text: RichTextLabel = found as RichTextLabel
		if not text.is_visible_in_tree() or not text.text.contains("[url="):
			continue
		marked += 1
		tips = await _rest_on_keyword(text)
		if tips != null:
			break
	if marked == 0:
		# The walk has bought what this store's counter held, and nothing left on the
		# page names a keyword: the next store is asked.
		_keyword_shot = false
		return
	if tips == null:
		var seen: Array[int] = [marked, _words_rested]
		_misclick("no keyword slip opened under the pointer (%d texts, %d words)" % seen)
		return
	await _shot("keyword_slip")
	var slips: Array = tips.call("slips")
	var slip: Control = slips[0]
	_point_at(slip.get_global_transform_with_canvas() * (slip.size / 2.0))
	await tree.create_timer(1.0).timeout
	slips = tips.call("slips")
	if slips.is_empty():
		_misclick("the keyword slip closed with the pointer on it")
	await _snap("keyword_slip_held")
	_point_at(Vector2(4, 4))
	await tree.create_timer(0.8).timeout


## Sweeps the pointer over text until a keyword's slip opens; null when none does.
func _rest_on_keyword(text: RichTextLabel) -> Object:
	var area: Rect2 = text.get_global_rect()
	var y: float = area.position.y + 8.0
	while y < area.end.y:
		var x: float = area.position.x + 4.0
		while x < area.end.x:
			_point_at(Vector2(x, y))
			Input.flush_buffered_events()
			await _frames(1)
			var tips: Object = tree.root.get_node_or_null("KeywordTips")
			if tips != null and not str(member(tips, "_asked_id")).is_empty():
				_words_rested += 1
				await tree.create_timer(0.5).timeout
				var open: Array = tips.call("slips")
				if not open.is_empty():
					return tips
			x += 8.0
		y += 10.0
	return null


## The state store's envelope: its offer with the slip, a few frames through the opening
## beat, the papers at rest, one focused, the same at the last corruption stage with the
## override put back, and one kept under its seal.
func _envelope_frames() -> void:
	if _envelope_shot:
		return
	var screen: Node = _current()
	var stall: Object = member(screen, "_envelope_stall")
	if stall == null or stall.call("panel", 0) == null:
		return
	_envelope_shot = true
	_grant_coupons(8)
	invoke(screen, "_refresh")
	await _frames(10)
	var offer: Control = stall.call("panel", 0)
	await _hover(offer)
	await _shot("store_envelope_offer")
	await _press(offer.get("buy"))
	for frame: int in 4:
		await _snap("envelope_opening_%d" % frame)
	var overlay: Object = stall.call("overlay")
	if overlay == null:
		_misclick("the envelope did not open")
		return
	await _settled(overlay)
	await _shot("envelope_choices")
	var papers: Array = overlay.call("papers")
	if papers.size() > 1:
		var second: Object = papers[1]
		var focused: Button = second.get("keep")
		focused.grab_focus()
		await _snap("envelope_choice_focused")
	await _worn(overlay as Node, "envelope_choices_stage_9")
	await _press(_first_keep(papers, overlay))
	await _requisition_choice(screen)
	await tree.create_timer(0.25).timeout
	await _snap("envelope_kept")
	await tree.create_timer(2.6).timeout
	if bool(stall.call("is_busy")):
		_fail("ENVELOPE STILL OPEN")


## A Requisition's deck card asks for the card it replaces (ADR 0042): the first deck card
## that may leave is clicked on the deck sheet, and the exchange confirmed.
func _requisition_choice(screen: Node) -> void:
	var sheet: Object = member(screen, "_deck")
	if not bool(sheet.call("is_open")):
		return
	await _shot("requisition_choose")
	var board: Object = sheet.call("board")
	for card_id: int in board.call("card_ids"):
		var card: CardInstance = board.call("card_of", card_id)
		if not bool(board.call("is_plot", card_id)) and card.base_rank() < Ranks.SMALL_JOKER:
			var view: Control = board.call("view_of", card_id)
			await _mouse_click(view.get_global_transform_with_canvas() * Vector2(14.0, 84.0))
			break
	await _press(sheet.call("confirm_button"))
	if bool(sheet.call("is_open")):
		_misclick("the requisition did not exchange")


## Coupons for a frame's purchase, in the state and in the record's checkpoint at the
## Set's end, so the purchase replays from the save.
func _grant_coupons(amount: int) -> void:
	var loop: RunLoop = _loop()
	loop.state.coupons += amount
	loop.record.checkpoint["coupons"] = int(loop.record.checkpoint["coupons"]) + amount
	# Handed over by this tool, so the second book is told (ADR 0022).
	_controller().call("reseal_book")


## The first Keep that can be pressed, or Take Nothing.
func _first_keep(papers: Array, overlay: Object) -> Button:
	for paper: Object in papers:
		var keep: Button = paper.get("keep")
		if not keep.disabled:
			return keep
	return overlay.call("nothing_button")


## A picture of whatever node shows at the last corruption stage, the override put back
## after.
func _worn(shown: Node, name: String) -> void:
	var was: int = ArtStages.stage_override
	ArtStages.stage_override = LAST_STAGE
	for node: Node in shown.find_children("*", "CanvasItem", true, false):
		(node as CanvasItem).queue_redraw()
	await _snap(name)
	ArtStages.stage_override = was
	for node: Node in shown.find_children("*", "CanvasItem", true, false):
		(node as CanvasItem).queue_redraw()
