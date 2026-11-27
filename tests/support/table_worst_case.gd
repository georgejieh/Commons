class_name TableWorstCase
extends RefCounted
## The table with every text piece holding the longest string of its family, measured in
## the piece's own type (ADR 0034), and each piece's place on screen by name, for the
## tests. ClipCheck sees each control against its own box; this sees the pieces against
## one another.

## The dressing the worst case puts up: the household notice and the extra chair keep
## clear of every piece; the room's chairs, the spotlight and the gilt lie under them.
const DRESSING: Array[String] = ["poster", "extra_chair", "empty_chairs", "gilt"]
## A full Campaign tray needs Courier's Bag.
const TRAY_REFORM: String = "couriers_bag"
const TRAY_SIZE: int = 3
## The most cards a hand or one play holds: the landlord's hand after the kitty.
const MOST_CARDS: int = 20
## Card ids for the staged play, clear of the deck's, which the hand holds.
const PLAY_IDS: int = 100
## The rules slip's width on the table: from the right seat's left edge to the action
## column's right edge.
const STRIP_WIDTH: float = 428.0


## Opens the table at a text size with the run's state set for the worst case: the player
## leading as landlord with the twenty cards the bid gave, a full Campaign tray of the
## longest names, and either the three debuffs that make the strip
## tallest in full, or, with named, the most the strip can ever name: the three debuffs
## with the longest names, every Reform held, a full board of the longest-named Cadres,
## and two wild ranks (set by fill); and either way the worst boss (BossWorstCase).
## Cadres are never on the strip (ADR 0039).
static func open(app: DemoApp, suite: GdUnitTestSuite, named: bool = false) -> TableScreen:
	var loop: RunLoop = app.controller.run_loop()
	var state: RunState = loop.state
	if state.landlord_seat != Seats.PLAYER:
		ControllerScript.new().take_landlord(suite, app.controller)
	if not state.reforms.has(TRAY_REFORM):
		state.reforms.append(TRAY_REFORM)
	state.inventory.consumables.assign(longest_campaigns(app))
	state.slogan_type = longest_slogan_type()
	var debuffs: Array[String] = []
	if named:
		for reform: ReformDef in RunPools.REFORMS.reforms:
			if not state.reforms.has(reform.id):
				state.reforms.append(reform.id)
		state.inventory.cadres.assign(longest_named_cadres(app.controller))
		debuffs = longest_named_debuffs(app.controller)
	else:
		state.inventory.cadres.clear()
		debuffs = await tallest_debuffs(app, suite)
	# A boss Set's slip holds its boss too (ADR 0043).
	await BossWorstCase.worst(app, suite, named)
	state.debuff_ladder.assign(["", debuffs[0], debuffs[1], debuffs[2]])
	state.round_index = 3
	var table: TableScreen = app.show_screen("table", true)
	await suite.await_idle_frame()
	await suite.await_idle_frame()
	return table


## Fills every text piece with its longest string. bidding shows Call and Pass in place of
## the play set; redacted lays the bars over the brigade notice; wild names two wild
## ranks on the slip; intel puts the tallest intel lines on both seats; armed arms the
## tray's first Campaign that can be used now, so Use and Cancel show.
static func fill(app: DemoApp, table: TableScreen, options: Dictionary) -> void:
	table.motion.set_still(true)
	var seats: Dictionary[int, SeatPanel] = table.seats
	var surname: String = longest_surname(app.controller)
	for seat: int in seats:
		var panel: SeatPanel = seats[seat]
		panel.setup(seat, surname)
		panel.set_role(seat == 2, false)
		var role: Label = panel.role
		panel.set_bid(widest(role, role_lines(), true))
		var count: Label = panel.count
		panel.set_count(_widest_count(count))
		var speech: Label = panel.speech_line
		panel.say(widest(speech, speech_lines()))
		panel.set_intel(
			IntelWorstCase.worst_intel(app, panel) if options.get("intel", false) else ""
		)
	var you: Label = table.you
	you.text = widest(you, _texts("table.you."))
	var actions: ActionBar = table.actions
	var bidding: bool = options.get("bidding", false)
	actions.show_bidding(bidding)
	var dressing: DreadDressing = table.dressing
	dressing.show_piece("redaction", 1.0 if options.get("redacted", false) else 0.0)
	# The first notice, which none stands taller than (test_brigade_notice).
	dressing.post_notice(DreadDressing.notice_key(1, 0))
	# Every piece of dressing up, so the pieces that must keep clear are seen doing it.
	for piece: String in DRESSING:
		dressing.show_piece(piece, 1.0)
	var hand: HandView = table.hand_view
	app.hand.refresh()
	hand.show_cards()
	var pile: TrickPile = table.pile
	pile.clear()
	pile.show_play(cards(PLAY_IDS), pile.global_position)
	var campaigns: TableCampaigns = table.campaigns
	var tray: CampaignTray = campaigns.tray
	tray.refresh()
	tray.visible = true
	tray.disarm()
	if options.get("armed", false):
		arm(tray)
	var strip: DebuffStrip = table.debuffs
	strip.wild_ranks = longest_wild_ranks() if options.get("wild", false) else ([] as Array[int])
	strip.show_debuffs(app.controller)
	var columns: TableColumns = table.columns
	columns.fit()
	# Last, as the hand and the tray set the prompt line whenever they change.
	actions.reading.text = tallest(actions.reading, PromptLines.every(app.controller, bidding))


## Arms the tray's first Campaign that can be used now, as a click on it does, and returns
## its slot, or -1 when none can be.
static func arm(tray: CampaignTray) -> int:
	for slot: int in tray.campaign_count():
		if tray.leaflet(slot).visible and tray.leaflet(slot).reason == RunController.CAMPAIGN_OK:
			tray.arm(slot)
			return tray.armed_slot()
	return -1


## Each piece of the table that must stay clear of the others, by name, as drawn.
static func pieces(table: TableScreen) -> Dictionary[String, Rect2]:
	var seats: Dictionary[int, SeatPanel] = table.seats
	var actions: ActionBar = table.actions
	var ledger: Control = table.ledger
	var dressing: DreadDressing = table.dressing
	var campaigns: TableCampaigns = table.campaigns
	var hud: Control = table.hud
	var board: Control = table.board
	var strip: Control = table.debuffs
	var you: Control = table.you
	var found: Dictionary[String, Rect2] = {
		"hud": hud.get_global_rect(),
		"left seat": seats[2].get_global_rect(),
		"right seat": seats[1].get_global_rect(),
		"Cadre board": board.get_global_rect(),
		"rules slip": strip.get_global_rect() if strip.visible else Rect2(),
		"trick pile": _pile_area(table.pile),
		"brigade notice": dressing.notice_rect(),
		"Campaign tray": _drawn_children(campaigns.tray),
		"status line": you.get_global_rect(),
		"prompt": actions.reading.get_global_rect(),
		"action buttons": _buttons(actions),
		"hand": _cards_area(table.hand_view),
		"ledger": (ledger.get_parent() as Control).get_global_rect(),
		"household notice": _piece_rect(dressing, "poster"),
		"extra chair": _piece_rect(dressing, "extra_chair"),
		"wall roster": dressing.roster_rect(),
	}
	return found


## A piece of dressing as drawn: its own box, or its parts' for a group; nothing hidden.
static func _piece_rect(dressing: DreadDressing, piece: String) -> Rect2:
	var pieces: Dictionary[String, Control] = dressing.pieces
	var control: Control = pieces[piece]
	if not control.is_visible_in_tree():
		return Rect2()
	if control.size != Vector2.ZERO:
		return control.get_global_rect()
	return _drawn_children(control)


## The rect a control covers as drawn, turned and scaled as it is.
static func drawn(control: Control) -> Rect2:
	var xform: Transform2D = control.get_global_transform()
	var box: Rect2 = Rect2(Vector2.ZERO, control.size)
	var area: Rect2 = Rect2(xform * box.position, Vector2.ZERO)
	for corner: Vector2 in [Vector2(box.end.x, 0.0), box.end, Vector2(0.0, box.end.y)]:
		area = area.expand(xform * corner)
	return area


static func _pile_area(pile: TrickPile) -> Rect2:
	var area: Rect2 = pile.get_global_rect()
	for child: Node in pile.get_children():
		if child is Control and (child as Control).visible:
			area = area.merge(drawn(child as Control))
	return area


static func _cards_area(hand: HandView) -> Rect2:
	var area: Rect2 = Rect2()
	for child: Node in hand.get_children():
		if child is CardView and (child as Control).visible:
			var card: Rect2 = drawn(child as Control)
			area = card if not area.has_area() else area.merge(card)
	return area


## The tray's head, leaflets and buttons as shown; the tray's own box is a holder.
static func _drawn_children(holder: Control) -> Rect2:
	var area: Rect2 = Rect2()
	for child: Node in holder.get_children():
		var shown: Control = child as Control
		if shown != null and shown.is_visible_in_tree() and shown.get_global_rect().has_area():
			var rect: Rect2 = shown.get_global_rect()
			area = rect if not area.has_area() else area.merge(rect)
	return area


static func _buttons(actions: ActionBar) -> Rect2:
	var area: Rect2 = Rect2()
	for button: Button in actions.find_children("*", "Button", true, false):
		if button.is_visible_in_tree():
			var rect: Rect2 = button.get_global_rect()
			area = rect if not area.has_area() else area.merge(rect)
	return area


## Twenty cards of ranks and suits that cycle, with ids from first.
static func cards(first: int) -> Array[CardInstance]:
	var made: Array[CardInstance] = []
	for index: int in MOST_CARDS:
		var rank: int = index % Ranks.SMALL_JOKER
		made.append(CardInstance.new(first + index, rank, index % 4, CardInstance.Origin.DECK))
	return made


## Of texts, the one widest on one line in label's type, upper-cased when upper.
static func widest(label: Label, texts: Array[String], upper: bool = false) -> String:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var best: String = ""
	var best_wide: float = -1.0
	for text: String in texts:
		var shown: String = text.to_upper() if upper else text
		var wide: float = font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if wide > best_wide:
			best = shown
			best_wide = wide
	return best


## Of texts, the one that wraps tallest in label's type at label's width, the wider of two
## as tall.
static func tallest(label: Label, texts: Array[String]) -> String:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var room: float = maxf(label.size.x, label.custom_minimum_size.x)
	var best: String = ""
	var best_size: Vector2 = Vector2(-1.0, -1.0)
	for text: String in texts:
		var tall: float = (
			font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, room, font_size).y
		)
		var wide: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if tall > best_size.y or (is_equal_approx(tall, best_size.y) and wide > best_size.x):
			best = text
			best_size = Vector2(wide, tall)
	return best


## What the role line can say: a role, a bid, or a flashed pass.
static func role_lines() -> Array[String]:
	var lines: Array[String] = _texts("table.role.")
	lines.append_array(_texts("bid."))
	for key: String in ["campaign.forced", "stamp.pass"]:
		lines.append(TranslationServer.translate(key))
	return lines


## Every count line a seat can show, from a full hand down to the last card.
static func _widest_count(label: Label) -> int:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var best: int = 1
	var best_wide: float = -1.0
	for cards_left: int in range(1, MOST_CARDS + 1):
		var text: String = SeatPanel.count_text(cards_left)
		var wide: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if wide > best_wide:
			best = cards_left
			best_wide = wide
	return best


## Every line a villager can say at the table.
static func speech_lines() -> Array[String]:
	var lines: Array[SpeechLine] = []
	lines.append_array(TableSpeech.BOOK.lines)
	lines.append_array(TableSpeech.VISIT.lines)
	var families: Array[FamilyDef] = []
	families.append_array(RunDefaults.VILLAGE.families)
	families.append_array(RunDefaults.VILLAGE.youth_templates)
	for family: FamilyDef in families:
		if family.speech != null:
			lines.append_array(family.speech.lines)
	var texts: Array[String] = []
	for line: SpeechLine in lines:
		texts.append(TranslationServer.translate(line.text_key).format({"count": 16}))
	return texts


## The three debuffs that stand tallest on the strip, each measured on a strip of the
## table's width at the text size now.
static func tallest_debuffs(app: DemoApp, suite: GdUnitTestSuite) -> Array[String]:
	var loop: RunLoop = app.controller.run_loop()
	var state: RunState = loop.state
	var strip: DebuffStrip = DebuffStrip.new()
	app.add_child(strip)
	strip.size = Vector2(STRIP_WIDTH, 0.0)
	var heights: Dictionary[String, float] = {}
	for debuff: ModifierDef in DebuffScript.POOL.debuffs:
		state.debuff_ladder.assign(["", debuff.id, "", ""])
		state.round_index = 1
		strip.show_debuffs(app.controller)
		await suite.await_idle_frame()
		heights[debuff.id] = strip.get_combined_minimum_size().y
	strip.queue_free()
	var ids: Array[String] = []
	ids.assign(heights.keys())
	ids.sort_custom(func(a: String, b: String) -> bool: return heights[a] > heights[b])
	return ids.slice(0, 3)


## The three debuffs with the longest names.
static func longest_named_debuffs(controller: RunController) -> Array[String]:
	var ids: Array[String] = []
	for debuff: ModifierDef in DebuffScript.POOL.debuffs:
		ids.append(debuff.id)
	var named: Callable = func(id: String) -> int:
		return controller.texts.modifier_name(id).length()
	ids.sort_custom(func(a: String, b: String) -> bool: return named.call(a) > named.call(b))
	return ids.slice(0, 3)


## The Cadres with the longest names, as many as the slots hold.
static func longest_named_cadres(controller: RunController) -> Array[String]:
	var ids: Array[String] = []
	for cadre: ModifierDef in RunLoop.all_cadres():
		if not ids.has(cadre.id):
			ids.append(cadre.id)
	var named: Callable = func(id: String) -> int:
		return controller.texts.modifier_name(id).length()
	ids.sort_custom(func(a: String, b: String) -> bool: return named.call(a) > named.call(b))
	return ids.slice(0, controller.figures.cadre_slots())


## The two wild ranks whose line on the strip is longest.
static func longest_wild_ranks() -> Array[int]:
	var best: Array[int] = [0, 1]
	for first: int in Ranks.TWO + 1:
		for second: int in range(first + 1, Ranks.TWO + 1):
			var pair: Array[int] = [first, second]
			if ReadingText.wild_line(pair).length() > ReadingText.wild_line(best).length():
				best = pair
	return best


## The Slogan's longest hand type, for the longest Slogan name.
static func longest_slogan_type() -> int:
	var best: int = Pattern.Type.PAIR
	var longest: int = 0
	for type: int in Pattern.Type.values():
		var key: String = "pattern.plural." + String(Pattern.Type.keys()[type]).to_lower()
		var shown: String = TranslationServer.translate(key)
		if shown != key and shown.length() > longest:
			longest = shown.length()
			best = type
	return best


## The held Campaigns with the longest names, as many as a full tray holds. Each of them
## can be used on the landlord's lead, so the armed tray is one the player can have.
static func longest_campaigns(app: DemoApp) -> Array[String]:
	var ids: Array[String] = []
	for pool: CampaignPool in [RunPools.STORE_CAMPAIGNS, RunPools.MARKET_CAMPAIGNS]:
		for campaign: CampaignDef in pool.campaigns:
			ids.append(campaign.id)
	var named: Callable = func(id: String) -> int:
		return app.controller.texts.campaign_name(id).length()
	ids.sort_custom(
		func(a: String, b: String) -> bool: return int(named.call(a)) > int(named.call(b))
	)
	return ids.slice(0, TRAY_SIZE)


## The village's longest surname, as a seat is named by it.
static func longest_surname(controller: RunController) -> String:
	return PromptLines.longest_seat_name(controller)


## Every string of the table whose key starts with prefix.
static func _texts(prefix: String) -> Array[String]:
	var texts: Array[String] = []
	for key: String in SourceScan.table_keys():
		if key.begins_with(prefix):
			texts.append(TranslationServer.translate(key))
	return texts
