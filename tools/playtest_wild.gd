extends RefCounted
## The playtest's frames of wild ranks (ADR 0029), in sandboxes put back after, the way
## the playtest's debuff and Campaign frames are: at the table, two Model Workers and
## Industrialization are handed over through the run's state and the first is used before
## the first play, so the call-out, the rules strip with one rank, the hand's ribbons at
## corruption stages 0, 4 and 9, the call-out and strip with two ranks and the Rules sheet's
## section are the real path; the picker with three or more readings and a soft bomb on
## the pile with its stand-ins are laid out from cards built here. In the state store each
## of the three items is put on its counter in turn. In the collection, a profile of three
## finished runs shows the wild tier locked. Loaded at run time by playtest.gd, so it
## reaches every UI node as Object, Node or Control, never by a ui/ class name.
## Development only; tools/ never ships.

const SETTLE_SECONDS: float = 1.2
const SNAP_SECONDS: float = 0.22
const WAIT_SECONDS: float = 20.0
## The corruption stages the hand's ribbons are photographed at.
const RIBBON_STAGES: Array[int] = [0, 4, 9]
const STEPS: int = 400
## Where a play on the pile is thrown from, the top of the play area.
const PILE_FROM: Vector2 = Vector2(790, 160)
const ITEMS: Array[String] = ["model_worker", "mass_line", "industrialization"]

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
func table(driver: Object) -> void:
	var controller: Object = _app.get("controller")
	var loop: RunLoop = controller.get("_loop")
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
	loop.set("_sets", SetConfig.new(params))
	loop.call("_rebuild_modifiers")
	_app.call("show_screen", "table", true)
	await _frames(20)
	if await _to_the_opening(controller, driver):
		await _use_and_photograph(controller)
	ArtStages.stage_override = was
	var saves: Object = _tree.root.get_node("Saves").call("run_service")
	saves.call("save", snapshot)
	_app.call("resume_to_screen")
	await _frames(30)


## Each of the three items on the state store's counter in turn, then the stock put back.
func store() -> void:
	var controller: Object = _app.get("controller")
	var loop: RunLoop = controller.get("_loop")
	var campaigns: Array[String] = loop.shop.campaigns.stock()
	var reforms: Array[String] = loop.shop.reforms.stock()
	# The demo's counters are drawn from the tiers below the wild ranks', so for these
	# frames they look items up in the whole pools; both are put back after.
	var campaign_pool: Array[CampaignDef] = loop.shop.campaigns.get("_pool")
	var reform_pool: Array[ReformDef] = loop.shop.reforms.get("_pool")
	loop.shop.campaigns.set("_pool", RunPools.STORE_CAMPAIGNS.campaigns.duplicate())
	loop.shop.reforms.set("_pool", RunPools.REFORMS.reforms.duplicate())
	var switcher: Object = _app.get("switcher")
	var screen: Node = switcher.call("current")
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
		loop.shop.campaigns.set("_stock", campaign_stock)
		loop.shop.reforms.set("_stock", reform_stock)
		screen.call("_refresh")
		await _frames(10)
		await _shot("store_wild_%s" % item_id)
	loop.shop.campaigns.set("_stock", campaigns)
	loop.shop.reforms.set("_stock", reforms)
	loop.shop.campaigns.set("_pool", campaign_pool)
	loop.shop.reforms.set("_pool", reform_pool)
	screen.call("_refresh")
	await _frames(10)


## The collection as a profile of three finished runs sees it, scrolled to the first
## locked sheet: the wild tier's, saying it opens after one more run.
func collection(locked_index: int) -> void:
	var switcher: Object = _app.get("switcher")
	var screen: Node = switcher.call("current")
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
		if int(controller.call("campaign_reason", 0, none, false)) == 0:
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
	var moments: Object = _part("_moments")
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
		var hand_view: Object = _part("_hand_view")
		hand_view.call("show_cards")
		await _frames(4)
		var ribbons: int = 0
		for view: Object in hand_view.call("views"):
			ribbons += 1 if bool(view.call("shows_wild")) else 0
		if ribbons == 0:
			print("NOTE no wild card in the hand at stage %d" % stage)
		await _shot("wild_hand_stage_%d" % stage)
	ArtStages.stage_override = -1
	_part("_hand_view").call("show_cards")


func _rules_frame() -> void:
	var actions: Object = _part("actions")
	var sheet: Object = _part("_cheat_sheet")
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
	var table: Object = controller.call("player_table")
	var readings: Array[Pattern] = _three_readings(table.get("rules"), table.get("rank_map"))
	if readings.size() < 3:
		_fail("NO CARDS READ THREE WAYS")
		return
	var wild: Object = _part("_wild")
	var picker: Object = wild.get("picker")
	picker.call("open", readings)
	await _frames(10)
	await _shot("wild_picker_%d_readings" % readings.size())
	picker.call("close")
	await _frames(4)


## A soft bomb on the pile: three of a rank and a wild card standing in, with the wild
## card's ribbon and the rank it stands for beside its own.
func _pile_frame(controller: Object) -> void:
	var wild: Array[int] = controller.call("wild_ranks")
	var table: Object = controller.call("player_table")
	var rank: int = _plain_rank(wild)
	var counts: PackedByteArray = PackedByteArray()
	counts.resize(Ranks.COUNT)
	counts[rank] = 3
	counts[wild[0]] = 1
	var reading: Pattern = Readings.of(counts, table.get("rules"), table.get("rank_map"))[0]
	var cards: Array[CardInstance] = []
	for suit: int in 3:
		cards.append(CardInstance.from_deck_id(rank * Deck.SUITS + suit))
	cards.append(CardInstance.from_deck_id(wild[0] * Deck.SUITS + 3))
	var pile: Object = _part("_pile")
	pile.call("clear")
	var none: Array[Vector2] = []
	pile.call("show_play", cards, PILE_FROM, none, reading)
	await _frames(30)
	await _shot("wild_pile_soft_bomb")
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


func _idle() -> bool:
	var events: Object = _part("_player")
	return events == null or bool(events.call("is_idle"))


## A part of the table now on screen, by its property or method name, or null off it.
func _part(part: String) -> Object:
	var switcher: Object = _app.get("switcher")
	var screen: Node = switcher.call("current")
	if screen == null or not is_instance_valid(screen) or screen.get("_player") == null:
		return null
	if screen.has_method(part):
		return screen.call(part)
	return screen.get(part)


func _until(ready: Callable, seconds: float = WAIT_SECONDS) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while not bool(ready.call()):
		if Time.get_ticks_msec() > deadline:
			return false
		await _frames(1)
	return true


func _fail(reason: String) -> void:
	print("MISS %s" % reason)
	misclicks += 1


func _frames(count: int) -> void:
	for _frame: int in count:
		await _tree.process_frame


func _snap(name: String) -> void:
	await _tree.create_timer(SNAP_SECONDS).timeout
	await _picture(name)


func _shot(name: String) -> void:
	await _tree.create_timer(SETTLE_SECONDS).timeout
	await _picture(name)


func _picture(name: String) -> void:
	shots += 1
	if _headless:
		print("FRAME %02d_%s" % [shots, name])
		return
	await RenderingServer.frame_post_draw
	var path: String = _out.path_join("%02d_%s.png" % [shots, name])
	_tree.root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
