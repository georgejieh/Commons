extends WalkBase
## The playtest's frames in the black market, taken once a run: the Parcel bought in a
## sandbox put back after, then the rank picker over the counter and the notice board
## holding Cadres that show counts. Development only; tools/ never ships.

var _parcel_shot: bool = false
var _market_shot: bool = false


## The black market's Parcel, in a sandbox put back after: its offer with the slip, then
## a Parcel holding a private Campaign, a stamped court card and a Model card, handed over
## through the run's state as only this tool does, and the stamped card kept.
func parcel() -> void:
	if _parcel_shot:
		return
	var screen: Node = _current()
	var stall: Object = member(screen, "envelope_stall")
	if stall == null or stall.call("panel", 0) == null:
		return
	_parcel_shot = true
	var loop: RunLoop = _loop()
	var snapshot: Dictionary = loop.record.to_dict()
	loop.state.coupons += 12
	loop.state.inventory.plot.clear()
	# Handed over by this tool for the frame, so the second book is told (ADR 0022).
	_controller().call("reseal_book")
	invoke(screen, "refresh")
	await _frames(10)
	var offer: Control = stall.call("panel", 0)
	await _hover(offer)
	await _shot("market_parcel_offer")
	await _press(offer.get("buy"))
	await _settled(stall.call("overlay"))
	var handed: Array[EnvelopeItem] = [
		EnvelopeItem.new(EnvelopeDef.Content.CAMPAIGN, "registration_drive"),
		EnvelopeItem.new(EnvelopeDef.Content.STAMPED_CARD, "", Ranks.KING, 1),
		EnvelopeItem.new(EnvelopeDef.Content.MODEL_CARD, "", Ranks.SEVEN, 3),
	]
	assign(loop.visit.market.envelopes, "_items", handed)
	var first: Node = stall.call("overlay")
	first.queue_free()
	assign(stall, "_overlay", null)
	stall.call("resume")
	await _frames(10)
	await _shot("parcel_choices")
	var overlay: Object = stall.call("overlay")
	var papers: Array = overlay.call("papers")
	var stamped: Object = papers[1]
	await _press(stamped.get("keep"))
	await tree.create_timer(0.25).timeout
	await _snap("parcel_kept")
	await tree.create_timer(2.6).timeout
	await _restore(snapshot)


## In the black market: the rank picker open over the counter with a ticket in focus,
## then the notice board holding Cadres that show counts, one of them firing. The stock,
## Cadres and counts are handed over through the run's state, which only this tool does,
## and put back after, so the run's record still replays.
func counter() -> void:
	if _market_shot:
		return
	_market_shot = true
	var screen: Node = _current()
	var controller: Object = _controller()
	var state: RunState = _loop().state
	var market: Object = _loop().visit.market
	var held: Array[String] = state.inventory.cadres.duplicate()
	var memos: Dictionary = state.cadre_memos.to_dict()
	var stock: Array[String] = member(market, "_stock")
	var coupons: int = state.coupons
	# One Cadre with art between two without, each with its full rules.
	assign(market, "_stock", ["rehabilitation", "hidden_reserves", "last_sheaf"] as Array[String])
	state.coupons = maxi(coupons, 40)
	# The coupons are a frame's, put back before any command; the second book is told.
	controller.call("reseal_book")
	invoke(screen, "refresh")
	await _frames(10)
	await _shot("black_market_cadre_rules")
	var counter: Node = member(member(screen, "cadres"), "row")
	await _press_in(counter.get_child(0))
	await _picker_frames(member(member(screen, "cadres"), "picker"))
	_hand_counted_cadres(state)
	invoke(screen, "refresh")
	await _shot("notice_board_counts")
	var board: Object = member(screen, "board")
	board.call("fired", controller, "seed_grain", 3)
	await _snap("notice_board_fired")
	state.inventory.cadres.assign(held)
	state.cadre_memos = CadreMemos.from_dict(memos)
	state.coupons = coupons
	controller.call("reseal_book")
	assign(market, "_stock", stock)
	invoke(screen, "refresh")
	await _frames(10)


## The rank picker open, a ticket in focus, then cancelled.
func _picker_frames(picker: Object) -> void:
	var chips: Array = picker.call("chips")
	await _shot("black_market_rank_picker")
	if chips.size() > Ranks.SEVEN:
		var seven: Control = chips[Ranks.SEVEN]
		seven.grab_focus()
		await _snap("black_market_rank_focus")
	await _press(member(picker, "cancel_button"))


## Cadres that show counts on the notice board, each with a count to show.
func _hand_counted_cadres(state: RunState) -> void:
	state.inventory.cadres.assign(
		["rehabilitation", "ration_coupon", "seed_grain", "steel_target", "stakhanovite"]
	)
	state.cadre_memos.entry("rehabilitation").put(CadreMemo.RANK, Ranks.SEVEN)
	state.cadre_memos.entry("ration_coupon").put(RationCouponEffect.EARNED, 2)
	state.cadre_memos.entry("seed_grain").put(SeedGrainEffect.MET, 3)
	state.cadre_memos.entry("steel_target").put(SteelTargetEffect.BOMBS, 2)
	state.cadre_memos.entry("stakhanovite").put(StakhanoviteEffect.LONG_STRAIGHTS, 1)
