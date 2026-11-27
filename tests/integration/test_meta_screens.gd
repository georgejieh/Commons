extends GdUnitTestSuite
## Run setup and the collection (ADR 0025) at 1920x1080 and at 1280x800: everything lies
## inside the screen across, and what a short screen cannot hold scrolls inside the page;
## keyboard and gamepad walk households, stakes, then Start, and the scroll follows; type
## a player must read is 16 px or more; and a locked sheet leaks nothing that names its
## item, in text, tooltip or accessible name.

const READABLE: int = 16

var _app: App
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)


func after_test() -> void:
	Settings.set_value(TextSize.SETTING, 0)
	get_tree().root.size = _was_size
	Saves.run_service().delete()
	Saves.profile_service().delete()


## A profile with three finished runs, the third stake unlocked and an heirloom to leave.
func _veteran() -> void:
	var data: ProfileData = ProfileData.new()
	data.finished_runs = 3
	data.generation = 3
	data.stake = 2
	data.lineage_kind = RunLineage.HEIRLOOM
	data.lineage_values = {RunLineage.RANK: Ranks.KING, RunLineage.SUIT: 1}
	Profile.write(Saves.profile_service(), data)


func _setup() -> RunSetupScreen:
	var screen: RunSetupScreen = _app.show_screen(ScreenId.RUN_SETUP, true)
	await await_idle_frame()
	await await_idle_frame()
	return screen


func _collection() -> CollectionScreen:
	var screen: CollectionScreen = _app.show_screen(ScreenId.COLLECTION, true)
	await await_idle_frame()
	await await_idle_frame()
	return screen


func test_a_fresh_profile_opens_one_household_and_one_stake() -> void:
	var screen: RunSetupScreen = await _setup()
	var papers: Array[AgedSheet] = screen.papers()
	assert_int(papers.size()).is_equal(RunStarter.HOUSEHOLDS.households.size())
	assert_bool(papers[0].choosable).is_true()
	assert_bool(papers[0].selected).is_true()
	for paper: AgedSheet in papers.slice(1):
		assert_bool(paper.choosable).is_false()
	var tickets: Array[StakeTicket] = screen.tickets()
	assert_int(tickets.size()).is_equal(6)
	assert_bool(tickets[0].open).is_true()
	assert_bool(tickets[0].picked).is_true()
	assert_str(tickets[1].words()).is_equal("Opens when you win at Base")
	# Every locked stake says how it opens; past the next, without naming one not reached.
	for ticket: StakeTicket in tickets.slice(2):
		assert_bool(ticket.open).is_false()
		assert_str(ticket.words()).is_equal("Opens when you win at the stake before")
	assert_str(screen.rules_text()).is_equal("The rules as written.")
	# The player's name for the run Start begins, then the generation (ADR 0028).
	assert_bool(_shows(screen, screen.player_name() + ", generation 1")).is_true()
	assert_bool(_shows(screen, "Inherited:")).is_false()
	assert_bool(_shows(screen, "Start with 4 coupons.")).is_true()
	assert_bool(_shows(screen, "Opens after 1 more run")).is_true()
	assert_bool(_shows(screen, "Opens after 3 more runs")).is_true()
	_assert_no_leak(screen, _household_names().slice(1))
	_assert_no_leak(screen, _stake_names().slice(1))


func test_a_veteran_sees_every_household_three_stakes_and_the_heirloom() -> void:
	_veteran()
	var screen: RunSetupScreen = await _setup()
	# Three runs open every household but ADR 0032's Returned Soldier, of tier 4.
	var households: Array[HouseholdDef] = RunStarter.HOUSEHOLDS.households
	var papers: Array[AgedSheet] = screen.papers()
	for index: int in papers.size():
		assert_bool(papers[index].choosable).is_equal(households[index].unlock_tier <= 3)
	var open: int = 0
	for ticket: StakeTicket in screen.tickets():
		open += 1 if ticket.open else 0
	assert_int(open).is_equal(3)
	assert_int(screen.stake()).is_equal(2)
	assert_str(screen.household()).is_equal("poor_peasants")
	assert_str(screen.rules_text()).is_equal(
		"Every Quota's target is 10% higher.\nThe state store offers 1 fewer Cadre."
	)
	assert_bool(_shows(screen, screen.player_name() + ", generation 4")).is_true()
	assert_bool(_shows(screen, "Inherited: a Model K of Hearts.")).is_true()
	var lines: Array[String] = [
		(
			"Start with 4 coupons and 2 cards in your private plot, ranked 10 to K."
			+ " The village holds 5 Resentment against you."
		),
		"Start with 10 coupons. The village holds 10 Resentment against you.",
		(
			"Start with 4 coupons and Landlord's Ledger. The village holds 15 Resentment"
			+ " against you, and Denunciation starts at 10."
		),
	]
	for line: String in lines:
		assert_bool(_shows(screen, line)).override_failure_message(line).is_true()
	assert_str(screen.tickets()[3].words()).is_equal("Opens when you win at Tight Books")
	_assert_no_leak(screen, _stake_names().slice(3))


func test_picking_and_starting_take_the_choice_and_it_is_not_remembered() -> void:
	_veteran()
	var screen: RunSetupScreen = await _setup()
	screen.papers()[3].chosen.emit()
	screen.tickets()[1].pressed.emit()
	assert_bool(screen.papers()[3].selected).is_true()
	assert_bool(screen.papers()[0].selected).is_false()
	assert_str(screen.rules_text()).is_equal("Every Quota's target is 10% higher.")
	screen.start_button().pressed.emit()
	await await_idle_frame()
	var state: RunState = _app.controller.state_copy()
	assert_str(state.identity.household).is_equal("old_family")
	assert_int(state.identity.stake).is_equal(1)
	assert_array(state.inventory.cadres).contains(["landlords_ledger"])
	assert_str(_app.switcher.current_id()).is_equal(ScreenId.SET_INTRO)
	var again: RunSetupScreen = await _setup()
	assert_str(again.household()).is_equal("poor_peasants")
	assert_int(again.stake()).is_equal(2)


func test_an_accept_press_or_click_picks_a_household() -> void:
	_veteran()
	var screen: RunSetupScreen = await _setup()
	var paper: AgedSheet = screen.papers()[2]
	paper.grab_focus()
	var accept: InputEventAction = InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	paper.grab_focus()
	TestInput.push(self, accept)
	assert_str(screen.household()).is_equal("shopkeepers")
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = screen.papers()[1].get_global_rect().get_center()
	TestInput.push(self, click)
	assert_str(screen.household()).is_equal("middle_peasants")


func test_focus_walks_households_then_stakes_then_start() -> void:
	_veteran()
	var screen: RunSetupScreen = await _setup()
	var start: Button = screen.start_button()
	assert_object(get_viewport().gui_get_focus_owner()).is_same(start)
	var papers: Array[AgedSheet] = screen.papers()
	var tickets: Array[StakeTicket] = screen.tickets()
	assert_object(start.find_valid_focus_neighbor(SIDE_TOP)).is_same(tickets[2])
	assert_object(tickets[1].find_valid_focus_neighbor(SIDE_TOP)).is_same(papers[0])
	assert_object(tickets[1].find_valid_focus_neighbor(SIDE_BOTTOM)).is_same(start)
	assert_object(papers[2].find_valid_focus_neighbor(SIDE_BOTTOM)).is_same(tickets[0])
	assert_object(papers[0].find_valid_focus_neighbor(SIDE_RIGHT)).is_same(papers[1])
	assert_object(tickets[0].find_valid_focus_neighbor(SIDE_RIGHT)).is_same(tickets[1])
	for control: Control in papers + tickets:
		assert_int(control.focus_mode).is_equal(Control.FOCUS_ALL)


func test_run_setup_fits_both_screens() -> void:
	for profile: bool in [false, true]:
		if profile:
			_veteran()
		for level: int in TextSize.count():
			Settings.set_value(TextSize.SETTING, level)
			for screen_size: Vector2i in ClipCheck.SIZES:
				get_tree().root.size = screen_size
				var screen: RunSetupScreen = await _setup()
				var where: String = "setup %s %s" % [profile, screen_size]
				_check_layout(screen, screen.scroll(), where)
				_check_type(screen, where)
				_clips(screen, where)
				# The whole page shows without scrolling at every text size, and the
				# stake row stands as wide as the household row.
				var content: Control = screen.scroll().get_child(0)
				assert_float(content.size.y).override_failure_message(where).is_less_equal(
					screen.scroll().size.y + ClipCheck.SLACK
				)
				var stakes: Control = screen.tickets()[0].get_parent()
				var households: Control = screen.papers()[0].get_parent()
				assert_float(stakes.size.x).override_failure_message(where).is_equal_approx(
					households.size.x, ClipCheck.SLACK
				)
				# Focus on the last ticket scrolls it into view.
				screen.tickets()[-1].grab_focus()
				await await_idle_frame()
				await await_idle_frame()
				var view: Rect2 = screen.scroll().get_global_rect().grow(ClipCheck.SLACK + 8.0)
				(
					assert_bool(view.encloses(screen.tickets()[-1].get_global_rect()))
					. override_failure_message(where)
					. is_true()
				)


## Every stake ticket's words are 16 px or more, on one or two lines, never broken inside
## a word, on the rank picker's warm paper with its red band; a locked ticket past the
## first says it opens with a win at the stake before. At both screen sizes, fresh and
## veteran.
func test_stake_tickets_read_at_16_px_on_warm_paper() -> void:
	for profile: bool in [false, true]:
		if profile:
			_veteran()
		for screen_size: Vector2i in ClipCheck.SIZES:
			get_tree().root.size = screen_size
			var screen: RunSetupScreen = await _setup()
			for ticket: StakeTicket in screen.tickets():
				var words: Label = ticket.words_label
				var where: String = "%s %s %s" % [profile, screen_size, ticket.words()]
				if ticket.words().is_empty():
					continue
				(
					assert_int(words.get_theme_font_size("font_size"))
					. override_failure_message(where)
					. is_greater_equal(16)
				)
				assert_int(words.get_line_count()).override_failure_message(where).is_less_equal(2)
				assert_bool(NameFit.label_fits(words)).override_failure_message(where).is_true()
				var shown: float = words.get_line_count() * words.get_line_height()
				assert_float(shown).override_failure_message(where).is_less_equal(
					words.size.y + ClipCheck.SLACK
				)


func test_the_collection_fits_both_screens_and_counts_whats_open() -> void:
	for profile: bool in [false, true]:
		if profile:
			_veteran()
		for level: int in TextSize.count():
			Settings.set_value(TextSize.SETTING, level)
			for screen_size: Vector2i in ClipCheck.SIZES:
				get_tree().root.size = screen_size
				var screen: CollectionScreen = await _collection()
				var where: String = "collection %s %s" % [profile, screen_size]
				_check_layout(screen, screen.scroll(), where)
				_check_type(screen, where)
				_clips(screen, where)
				var view: CollectionView = CollectionView.for_runs(3 if profile else 0)
				var line: String = "%d of %d open" % [view.open_count(), view.total()]
				assert_str(screen.open_line()).is_equal(line)
				assert_int(screen.entries().size()).is_equal(view.total())
				if profile:
					# Three runs open every tier but the wild ranks' three items (ADR 0029) and
					# ADR 0032's three of tier 4 and two of tier 5.
					assert_int(view.total() - view.open_count()).is_equal(8)
	var fresh: CollectionView = CollectionView.for_runs(0)
	assert_int(fresh.open_count()).is_less(fresh.total())


func test_a_fresh_collections_locked_sheets_name_nothing() -> void:
	var screen: CollectionScreen = await _collection()
	var view: CollectionView = CollectionView.for_runs(0)
	var locked: Array[String] = []
	var blanks: int = 0
	for section: int in view.section_keys().size():
		for sheet: UnlockSheet in view.sheets(section):
			if sheet.open:
				continue
			blanks += 1
			assert_str(sheet.name).is_empty()
			assert_str(sheet.text).is_empty()
			assert_str(sheet.id).is_empty()
	for item: Resource in _all_items():
		if int(item.get("unlock_tier")) > 0:
			locked.append(tr(str(item.get("name_key"))))
	assert_int(blanks).is_equal(locked.size())
	_assert_no_leak(screen, locked)
	# The scroll's own hints are pictures too, so only its content is counted.
	var sheets: Node = screen.scroll().get_child(0)
	var art: int = sheets.find_children("*", "ArtFrame", true, false).size()
	art += sheets.find_children("*", "TextureRect", true, false).size()
	var open_cadres: int = 0
	for cadre: ModifierDef in RunLoop.all_cadres():
		open_cadres += 1 if cadre.unlock_tier == 0 else 0
	# One picture or frame per open Cadre, and none for a locked one.
	assert_int(art).is_equal(open_cadres)
	# Focus on the last sheet scrolls the page to it.
	var entries: Array[Control] = screen.entries()
	for entry: Control in entries:
		assert_int(entry.focus_mode).is_equal(Control.FOCUS_ALL)
	entries[-1].grab_focus()
	await await_idle_frame()
	await await_idle_frame()
	assert_int(screen.scroll().scroll_vertical).is_greater(0)


## Every Label, tooltip and accessible name under root, none holding any of the names.
func _assert_no_leak(root: Node, names: Array) -> void:
	for node: Node in root.find_children("*", "Control", true, false):
		var control: Control = node as Control
		var said: PackedStringArray = [control.tooltip_text, control.accessibility_name]
		said.append(control.accessibility_description)
		if control is Label:
			said.append((control as Label).text)
		for text: String in said:
			for entry: Variant in names:
				var named: String = str(entry)
				if named.is_empty():
					continue
				(
					assert_bool(text.contains(named))
					. override_failure_message("%s names %s" % [control.get_path(), named])
					. is_false()
				)


func _shows(root: Node, text: String) -> bool:
	for node: Node in root.find_children("*", "Label", true, false):
		if (node as Label).text.contains(text) and (node as Label).is_visible_in_tree():
			return true
	return false


## Inside the scroll, nothing passes its sides; outside it, everything is on screen; and
## the scroll itself is on screen.
func _check_layout(root: Control, scroll: ScrollContainer, where: String) -> void:
	var screen: Rect2 = get_tree().root.get_visible_rect().grow(ClipCheck.SLACK)
	var lane: Rect2 = scroll.get_global_rect().grow(ClipCheck.SLACK)
	assert_bool(screen.encloses(lane)).override_failure_message(where).is_true()
	for node: Node in root.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if not control.is_visible_in_tree() or control is TextureRect or control is ColorRect:
			continue
		var rect: Rect2 = control.get_global_rect()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0 or control is ScrollBar:
			continue
		var failure: String = "%s: %s at %s" % [where, control.get_path(), rect]
		if scroll.is_ancestor_of(control):
			var across: bool = rect.position.x >= lane.position.x and rect.end.x <= lane.end.x
			assert_bool(across).override_failure_message(failure).is_true()
		else:
			assert_bool(screen.encloses(rect)).override_failure_message(failure).is_true()


func _check_type(root: Node, where: String) -> void:
	for node: Node in root.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label.text.is_empty() or not label.is_visible_in_tree():
			continue
		var size_used: int = label.get_theme_font_size("font_size")
		(
			assert_int(size_used)
			. override_failure_message("%s: %s %d" % [where, label.text, size_used])
			. is_greater_equal(READABLE)
		)


func _household_names() -> Array[String]:
	var names: Array[String] = []
	for household: HouseholdDef in RunStarter.HOUSEHOLDS.households:
		names.append(tr(household.name_key))
	return names


func _stake_names() -> Array[String]:
	var names: Array[String] = []
	for stake: StakeDef in RunStakes.STAKES.stakes:
		names.append(tr(stake.name_key))
	return names


func _all_items() -> Array[Resource]:
	var items: Array[Resource] = []
	items.append_array(RunLoop.all_cadres())
	items.append_array(RunCampaigns.all())
	items.append_array(RunPools.DIRECTIVES.directives)
	items.append_array(RunReforms.all())
	items.append_array(RunPools.STORE.envelopes + RunPools.MARKET.envelopes)
	return items


## Nothing under root clips, as ClipCheck says (ADR 0034).
func _clips(root: Node, where: String) -> void:
	var problems: PackedStringArray = []
	ClipCheck.check(root, "%s at text size %d" % [where, TextSize.level()], problems)
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()
