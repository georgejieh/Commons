extends WalkBase
## The playtest's frames of wild ranks (ADR 0029), in sandboxes put back after, the way
## the playtest's debuff and Campaign frames are: at the table, two Model Workers and
## Industrialization are handed over through the run's state and the first is used before
## the first play, so the call-out, the rules strip with one rank, the hand's ribbons at
## corruption stages 0, 4 and 9, the call-out and strip with two ranks and the Rules
## sheet's section are the real path; the picker with three or more readings and a soft
## bomb on the pile with its stand-ins, then a villager's pair of the wild rank landing
## plain, are laid out from cards built here. In the state store each of the three items
## is put on its counter in turn. In the collection, a profile of three finished runs
## shows the wild tier locked. It also forces a Cadre of the top rarity onto either
## shop's counter, for its Scarce stamp landing and at rest (scarce()).
## Development only; tools/ never ships.

## The corruption stages the hand's ribbons are photographed at.
const RIBBON_STAGES: Array[int] = [0, 4, 9]
const STEPS: int = 400
## Where a play on the pile is thrown from, the top of the play area.
const PILE_FROM: Vector2 = Vector2(790, 160)
const ITEMS: Array[String] = ["model_worker", "mass_line", "industrialization"]
## A Cadre of the top rarity from each shop's pool, and the pools they are looked up in.
const SCARCE: Array[String] = ["seed_grain", "rent_book"]
const POOLS: Array[String] = ["res://data/run/cadre_pool.tres", "res://data/run/market_pool.tres"]
const PRESETS: MotionPresets = preload("res://data/ui/motion_presets.tres")
## How far through its landing the Scarce stamp is photographed, as shares of its time.
const LANDING: Array[float] = [0.3, 0.6]


## The table's frames, from the round under way, put back as they were after.
func table(driver: Object) -> void:
	var controller: Object = _controller()
	var loop: RunLoop = _loop()
	var snapshot: Dictionary = loop.record.to_dict()
	var was: int = ArtStages.stage_override
	loop.state.inventory.consumables.assign(["model_worker", "model_worker"])
	# No plot, so no swap waits between the bid and the opening.
	loop.state.inventory.plot.clear()
	if not loop.state.reforms.has("industrialization"):
		loop.state.reforms.append("industrialization")
	var params: SetParams = SetConfig.DEFAULT_PARAMS.duplicate()
	params.targets = params.targets.duplicate()
	params.targets.fill(1e9)
	assign(loop, "_sets", SetConfig.new(params))
	invoke(loop, "rebuild_modifiers")
	app.call("show_screen", "table", true)
	await _frames(20)
	if await _to_the_opening(controller, driver):
		await _use_and_photograph(controller)
	ArtStages.stage_override = was
	await _restore(snapshot)


## Each of the three items on the state store's counter in turn, then the stock put back.
func store() -> void:
	var loop: RunLoop = _loop()
	var campaigns: Array[String] = loop.visit.shop.campaigns.stock()
	var reforms: Array[String] = loop.visit.shop.reforms.stock()
	# The demo's counters are drawn from the tiers below the wild ranks', so for these
	# frames they look items up in the whole pools; both are put back after.
	var campaign_pool: Array[CampaignDef] = member(loop.visit.shop.campaigns, "_pool")
	var reform_pool: Array[ReformDef] = member(loop.visit.shop.reforms, "_pool")
	assign(loop.visit.shop.campaigns, "_pool", RunPools.STORE_CAMPAIGNS.campaigns.duplicate())
	assign(loop.visit.shop.reforms, "_pool", RunPools.REFORMS.reforms.duplicate())
	var screen: Node = _current()
	for item_id: String in ITEMS:
		var campaign_stock: Array[String] = campaigns.duplicate()
		var reform_stock: Array[String] = reforms.duplicate()
		if item_id == "model_worker":
			if campaign_stock.is_empty():
				campaign_stock.append(item_id)
			campaign_stock[0] = item_id
		else:
			if reform_stock.is_empty():
				reform_stock.append(item_id)
			reform_stock[0] = item_id
		assign(loop.visit.shop.campaigns, "_stock", campaign_stock)
		assign(loop.visit.shop.reforms, "_stock", reform_stock)
		invoke(screen, "refresh")
		await _frames(10)
		await _shot("store_wild_%s" % item_id)
	assign(loop.visit.shop.campaigns, "_stock", campaigns)
	assign(loop.visit.shop.reforms, "_stock", reforms)
	assign(loop.visit.shop.campaigns, "_pool", campaign_pool)
	assign(loop.visit.shop.reforms, "_pool", reform_pool)
	invoke(screen, "refresh")
	await _frames(10)


## A Cadre of the top rarity on the first place of a shop's counter (the black market's
## with market), stamped Scarce: the stamp part way through its landing, its clock held,
## then at rest. The counter is put back after.
func scarce(market: bool) -> void:
	var loop: RunLoop = _loop()
	var shop: RunShop = loop.visit.market if market else loop.visit.shop
	var stock: Array[String] = shop.stock()
	var pool: Array[ModifierDef] = member(shop, "_pool")
	var whole: CadrePool = load(POOLS[int(market)])
	var forced: Array[String] = stock.duplicate()
	if forced.is_empty():
		forced.append(SCARCE[int(market)])
	forced[0] = SCARCE[int(market)]
	assign(shop, "_pool", whole.cadres.duplicate())
	assign(shop, "_stock", forced)
	var screen: Node = _current()
	invoke(screen, "refresh")
	await _frames(10)
	var name: String = "market_scarce" if market else "store_scarce"
	var stamp: Control = null
	for node: Node in screen.find_children("*", "Control", true, false):
		if node.has_method("land"):
			stamp = node as Control
			break
	if stamp == null:
		_fail("NO SCARCE STAMP")
	else:
		var landing: Tween = stamp.call("land")
		if landing != null:
			landing.pause()
			var at: float = 0.0
			for index: int in LANDING.size():
				landing.custom_step((LANDING[index] - at) * PRESETS.stamp_time)
				at = LANDING[index]
				await _frames(2)
				await _picture("%s_landing_%d" % [name, index])
			landing.custom_step(PRESETS.stamp_time)
		await _shot(name)
	assign(shop, "_stock", stock)
	assign(shop, "_pool", pool)
	invoke(screen, "refresh")
	await _frames(10)


## The collection as a profile of three finished runs sees it, scrolled to the first
## locked sheet: the wild tier's, saying it opens after one more run.
func collection(locked_index: int) -> void:
	var screen: Node = _current()
	var entries: Array = screen.call("entries")
	if locked_index < 0 or locked_index >= entries.size():
		_fail("NO LOCKED WILD SHEET")
		return
	var entry: Control = entries[locked_index]
	entry.grab_focus()
	await _frames(10)
	await _shot("collection_wild_locked")


## Plays on until a Model Worker may be used: a peasant's opening or the landlord
## player's first turn. Every part of the table is looked up afresh each time.
func _to_the_opening(controller: Object, driver: Object) -> bool:
	for _step: int in STEPS:
		await _until(_idle)
		var none: Array[int] = []
		if int(view(controller, "items").call("campaign_reason", 0, none, false)) == 0:
			return true
		if not bool(driver.call("act", controller)):
			await _frames(5)
	_fail("NO MOMENT FOR MODEL WORKER")
	return false


func _use_and_photograph(controller: Object) -> void:
	var none: Array[int] = []
	if int(controller.call("campaign", 0, none)) != 0:
		_fail("MODEL WORKER REFUSED")
		return
	await _callout_frames("wild_callout")
	await _until(_idle)
	await _shot("wild_strip_one")
	if int(controller.call("campaign", 0, none)) != 0:
		_fail("SECOND MODEL WORKER REFUSED")
		return
	await _callout_frames("wild_callout_two")
	await _until(_idle)
	await _shot("wild_strip_two")
	# With two ranks wild the hand is all but sure to hold a wild card.
	await _ribbon_frames()
	await _rules_frame()
	await _picker_frame(controller)
	await _pile_frame(controller)


## The call-out in motion, once it is on screen.
func _callout_frames(name: String) -> void:
	var moments: Object = _part("moments")
	var callout: Object = moments.get("callout") if moments != null else null
	if callout == null or not await _until(func() -> bool: return callout.call("is_showing")):
		_fail("NO WILD CALL-OUT")
		return
	for frame: int in 2:
		await _snap("%s_%d" % [name, frame])


## The hand with its wild cards at each stage, drawn again at each.
func _ribbon_frames() -> void:
	for stage: int in RIBBON_STAGES:
		ArtStages.stage_override = stage
		var hand_view: Object = _part("hand_view")
		hand_view.call("show_cards")
		await _frames(4)
		var ribbons: int = 0
		for card_view: Object in hand_view.call("views"):
			ribbons += 1 if bool(card_view.call("shows_wild")) else 0
		if ribbons == 0:
			print("NOTE no wild card in the hand at stage %d" % stage)
		await _shot("wild_hand_stage_%d" % stage)
	ArtStages.stage_override = -1
	_part("hand_view").call("show_cards")


func _rules_frame() -> void:
	var actions: Object = _part("actions")
	var sheet: Object = _part("cheat_sheet")
	var rules: Button = actions.get("rules")
	rules.pressed.emit()
	await _frames(10)
	if str(sheet.call("wild_text")).is_empty():
		_fail("NO WILD SECTION ON THE RULES SHEET")
	await _shot("wild_rules_sheet")
	sheet.set("visible", false)
	await _frames(4)


## The picker over the table on cards that read three ways or more, built from the
## player's rules now; it is photographed and closed, and nothing is played.
func _picker_frame(controller: Object) -> void:
	var seat_table: Object = view(controller, "table").call("player_table")
	var readings: Array[Pattern] = _three_readings(
		seat_table.get("rules"), seat_table.get("rank_map")
	)
	if readings.size() < 3:
		_fail("NO CARDS READ THREE WAYS")
		return
	var wild: Object = _part("wild")
	var picker: Object = wild.get("picker")
	# Beside the fan, as over cards the player had chosen; nothing here is chosen.
	var hand: Control = _part("hand_view") as Control
	picker.call("open", readings, hand.get_global_rect())
	await _frames(10)
	await _shot("wild_picker_%d_readings" % readings.size())
	picker.call("close")
	await _frames(4)


## A soft bomb on the pile: three of a rank and a wild card standing in, with the wild
## card's ribbon and the rank it stands for beside its own.
func _pile_frame(controller: Object) -> void:
	var wild: Array[int] = view(controller, "table").call("wild_ranks")
	var seat_table: Object = view(controller, "table").call("player_table")
	var rank: int = _plain_rank(wild)
	var counts: PackedByteArray = PackedByteArray()
	counts.resize(Ranks.COUNT)
	counts[rank] = 3
	counts[wild[0]] = 1
	var reading: Pattern = (
		Readings.of(counts, seat_table.get("rules"), seat_table.get("rank_map"))[0]
	)
	var cards: Array[CardInstance] = []
	for suit: int in 3:
		cards.append(Deck.new().card(rank * Deck.SUITS + suit))
	cards.append(Deck.new().card(wild[0] * Deck.SUITS + 3))
	var pile: Object = _part("pile")
	pile.call("clear")
	var none: Array[Vector2] = []
	pile.call("show_play", cards, PILE_FROM, none, reading)
	await _frames(30)
	await _shot("wild_pile_soft_bomb")
	# A villager's pair of the player's wild rank lands plain (ADR 0039): no ribbon.
	var pair: Array[CardInstance] = [
		Deck.new().card(wild[0] * Deck.SUITS),
		Deck.new().card(wild[0] * Deck.SUITS + 1),
	]
	pile.call("show_play", pair, PILE_FROM, none, null, false)
	await _frames(30)
	await _shot("wild_pile_villager_plain")
	pile.call("clear")


## The first set of cards, from a few shapes over the ranks that are not wild, that reads
## three ways or more under these rules, strongest first; or the most found.
func _three_readings(rules: RuleSet, rank_map: PackedByteArray) -> Array[Pattern]:
	var wild: Array[int] = rules.wild_ranks()
	var shapes: Array[Array] = [[4, 0], [3, 0], [3, 1], [2, 2], [3, 3], [4, 1]]
	var best: Array[Pattern] = []
	for rank: int in Ranks.ACE:
		if wild.has(rank) or wild.has(rank + 1):
			continue
		for shape: Array in shapes:
			var counts: PackedByteArray = PackedByteArray()
			counts.resize(Ranks.COUNT)
			counts[rank] = shape[0]
			counts[rank + 1] = shape[1]
			for wild_rank: int in wild:
				counts[wild_rank] += 1
			var found: Array[Pattern] = Readings.of(counts, rules, rank_map)
			if found.size() >= 3:
				return found
			if found.size() > best.size():
				best = found
	return best


static func _plain_rank(wild: Array[int]) -> int:
	for rank: int in [Ranks.NINE, Ranks.EIGHT, Ranks.TEN, Ranks.SIX]:
		if not wild.has(rank):
			return rank
	return Ranks.THREE
