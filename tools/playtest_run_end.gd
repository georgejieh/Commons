extends WalkBase
## The playtest's frames after the demo's rounds, each in a sandbox put back after: every
## ending and both deaths, then a full run once with the pages a profile changes (run
## setup, the collection, the village history, the card backs, the table at each
## corruption stage) and the pause menu's Abandon. Development only; tools/ never ships.

const FileWalk := preload("res://tools/playtest_file.gd")
const Wild := preload("res://tools/playtest_wild.gd")
## The seed of each run built here, so its frames are the same each time.
const SEED: int = 4242
## The profile corruption values the table is photographed at: stages 0, 3, 6 and 9.
const CORRUPTION_VALUES: Array[int] = [5, 35, 65, 95]
## Each ending and death the playtest finishes a run on (ADR 0024): Famine, Denunciation,
## Resentment and rounds as landlord of the final Year's four.
const ENDING_RUNS: Dictionary[String, Array] = {
	"secret_contract": [30, 20, 40, 0],
	"the_commons": [10, 10, 0, 0],
	"lean_years": [80, 20, 40, 1],
	"labeled": [20, 80, 40, 1],
	"benevolent_landlord": [30, 30, 40, 3],
	"full_granary": [85, 40, 40, 4],
	"struggled": [40, 90, 40, 2],
	"death_famine": [100, 40, 40, 1],
	"death_denunciation": [40, 100, 40, 1],
}


## Every ending and both deaths, once: a finished run with a full village is saved at the
## run's end and continued, so the ending screen opens the way a real run's end opens it.
## The Secret Contract's epilogue is photographed as it arrives; every page is then shown
## whole with an accept press, and Struggled once more at the last corruption stage. Last,
## Return to title is clicked, the save taken before is written back and the run resumed.
func endings() -> void:
	var snapshot: Dictionary = _loop().record.to_dict()
	var saves: Object = tree.root.get_node("Saves").call("run_service")
	for outcome: String in ENDING_RUNS:
		var screen: Node = await _open_ending(outcome, saves)
		if outcome == "secret_contract":
			await tree.create_timer(0.5).timeout
			for frame: int in 3:
				await _snap("ending_secret_contract_epilogue_%d" % frame)
				await tree.create_timer(1.1).timeout
		await _accept_epilogue(screen)
		var death: bool = outcome.begins_with("death_")
		await _shot(outcome if death else "ending_" + outcome)
	var was: int = ArtStages.stage_override
	ArtStages.stage_override = LAST_STAGE
	var worn: Node = await _open_ending("struggled", saves)
	await _accept_epilogue(worn)
	await _shot("ending_struggled_stage_9")
	ArtStages.stage_override = was
	await _press(worn.call("home_button"))
	await _frames(20)
	if _screen_id() != "title":
		_misclick("the ending did not go home")
	await _restore(snapshot)


## A full run once (ADR 0025): New Run without --demo starts the eight-Year run, whose
## first Set intro names the families at the table; the title then offers Continue for
## it, and Continue picks it up as a full run; the pause menu's Abandon asks first, with
## the focus on Keep playing, and clears the save. Then the demo's save is written back
## and the demo flow resumed. file and wild_ranks are the walks of those frames.
func full_run(file: FileWalk, wild_ranks: Wild) -> void:
	var saves: Object = tree.root.get_node("Saves").call("run_service")
	var controller: Object = _controller()
	var snapshot: Dictionary = _loop().record.to_dict()
	app.set("demo", false)
	var profile: SaveService = tree.root.get_node("Saves").call("profile_service")
	var kept: Dictionary[String, String] = _keep_files(profile)
	await _meta_frames(profile, wild_ranks)
	await _history_frames(profile)
	await _card_back_frames(profile)
	await _corruption_frames(profile)
	await file.meta(profile)
	Profile.write(profile, ProfileData.new())
	app.call("show_screen", "title", true)
	await _frames(20)
	await _click_button_with_text(tr("title.new_run"))
	var promised: String = _current().call("player_name")
	await _click_button_with_text(tr("setup.start"))
	await _frames(20)
	_expect(bool(view(controller, "seats").call("has_village")), "FULL RUN NOT STARTED")
	var named: String = view(controller, "seats").call("player_name")
	_expect(named == promised, "RUN NAME %s IS NOT SETUP'S %s" % [named, promised])
	await _shot("full_run_set_intro")
	await _dossier_names()
	var menu: Node = member(app, "menu")
	menu.call("open")
	await _frames(10)
	await _press_text_in(menu, tr("pause.to_title"))
	await _frames(30)
	await _shot("title_full_run")
	_expect(_button_in(_current(), tr("title.continue")) != null, "NO CONTINUE")
	await _click_button_with_text(tr("title.continue"))
	await _frames(40)
	_expect(bool(view(controller, "seats").call("has_village")), "RESUME WRONG KIND")
	_expect(_screen_id() == "table", "RESUME WRONG SCREEN")
	await _abandon_frames(_current(), saves)
	_put_back_files(kept)
	saves.call("save", snapshot, ContentStamp.extras())
	app.set("demo", true)
	app.call("resume_to_screen")
	await _frames(30)


## The dossier names each seated villager in full, given name first (ADR 0028).
func _dossier_names() -> void:
	app.call("show_screen", "dossier")
	await _frames(20)
	await _shot("dossier_names")
	var page: Node = _current()
	for seat: int in [1, 2]:
		var full: String = view(_controller(), "seats").call("seated_full_name", seat)
		var whole: bool = full.split(" ").size() == 2 and _shows_text(page, full)
		_expect(whole, "DOSSIER SEAT %d NAMED %s" % [seat, full])
	app.call("back")
	await _frames(20)


## True when a label under node shows text.
func _shows_text(node: Node, text: String) -> bool:
	for found: Node in node.find_children("*", "Label", true, false):
		var shown: Label = found as Label
		if shown.is_visible_in_tree() and shown.text.contains(text):
			return true
	return false


## Run setup and the collection for a fresh profile and for one handed three finished
## runs, the third stake and an heirloom (ADR 0025): one household and one stake open,
## then all four households, three stakes and the inherited line; every item locked but
## tier 0's, then every item open. A click on The Old Family picks it.
func _meta_frames(profile: SaveService, wild_ranks: Wild) -> void:
	Profile.write(profile, ProfileData.new())
	app.call("show_screen", "title", true)
	await _frames(20)
	await _click_button_with_text(tr("title.collection"))
	await _shot("collection_locked")
	var shown: String = _current().call("open_line")
	_expect(shown == CollectionView.for_runs(0).open_line(), "COLLECTION COUNT WRONG")
	await _click_button_with_text(tr("coll.back"))
	await _click_button_with_text(tr("title.new_run"))
	await _shot("run_setup_full")
	var setup: Node = _current()
	var player: String = setup.call("player_name")
	var full: bool = player.split(" ").size() == 2 and _shows_text(setup, player)
	_expect(full, "RUN SETUP SHOWS NO FULL NAME %s" % player)
	var open: int = 0
	for paper: Control in setup.call("papers"):
		open += 1 if bool(paper.get("choosable")) else 0
	_expect(open == 1, "FRESH SETUP OPENS %d HOUSEHOLDS" % open)
	await _click_button_with_text(tr("setup.back"))
	Profile.write(profile, _veteran())
	await _click_button_with_text(tr("title.new_run"))
	setup = _current()
	var papers: Array = setup.call("papers")
	var old_family: Control = papers[3]
	await _mouse_click(old_family.get_global_transform_with_canvas() * (old_family.size / 2.0))
	await _frames(10)
	if setup.call("household") != "old_family":
		_misclick("the household click missed")
	await _shot("run_setup_veteran")
	_expect(int(setup.call("stake")) == 2, "VETERAN STAKE WRONG")
	await _click_button_with_text(tr("setup.back"))
	await _click_button_with_text(tr("title.collection"))
	await _shot("collection_open")
	await wild_ranks.collection(_first_locked_sheet())
	shown = _current().call("open_line")
	_expect(shown == CollectionView.for_runs(3).open_line(), "OPEN COLLECTION COUNT WRONG")
	await _click_button_with_text(tr("coll.back"))


## A profile handed three finished runs, the third stake and an heirloom.
func _veteran() -> ProfileData:
	var veteran: ProfileData = ProfileData.new()
	veteran.finished_runs = 3
	veteran.generation = 3
	veteran.stake = 2
	veteran.lineage_kind = "heirloom"
	veteran.lineage_values = {"rank": Ranks.KING, "suit": 1}
	return veteran


## Where in the collection of a profile with three finished runs the first locked sheet
## stands, or -1: the wild tier's.
func _first_locked_sheet() -> int:
	var view: CollectionView = CollectionView.for_runs(3)
	var index: int = 0
	for section: int in view.section_keys().size():
		for sheet: UnlockSheet in view.sheets(section):
			if not sheet.open:
				return index
			index += 1
	return -1


## The village history for a profile handed four finished runs, newest first: one with
## families dead, one a death, both classes.
func _history_frames(profile: SaveService) -> void:
	var data: ProfileData = ProfileData.new()
	var runs: Array[Array] = [
		[1, Endings.SECRET_CONTRACT, HistoryEntry.PEASANT, []],
		[2, Endings.LEAN_YEARS, HistoryEntry.PEASANT, [0, 3]],
		[3, Endings.DEATH_FAMINE, HistoryEntry.LANDLORD, []],
		[4, Endings.BENEVOLENT_LANDLORD, HistoryEntry.LANDLORD, [5]],
	]
	for values: Array in runs:
		var entry: HistoryEntry = HistoryEntry.new()
		entry.run_id = "playtest-%d" % values[0]
		entry.generation = values[0]
		entry.outcome = values[1]
		entry.class_id = values[2]
		entry.year = 3 if Endings.is_death(entry.outcome) else 8
		for family: int in values[3]:
			entry.dead.append(RunDefaults.VILLAGE.families[family].name_key)
		data.add_history(entry)
	data.finished_runs = runs.size()
	Profile.write(profile, data)
	app.call("show_screen", "title", true)
	await _frames(20)
	await _click_button_with_text(tr("title.history"))
	var records: Array = _current().call("records")
	_expect(records.size() == runs.size(), "HISTORY HOLDS THE WRONG COUNT")
	await _shot("history_generations")
	await _click_button_with_text(tr("hist.back"))


## Settings with the card back row: the open design chosen, the others blank sheets.
func _card_back_frames(profile: SaveService) -> void:
	var data: ProfileData = ProfileData.new()
	data.finished_runs = 2
	Profile.write(profile, data)
	app.call("show_screen", "title", true)
	await _frames(20)
	await _click_button_with_text(tr("title.settings"))
	var row: Object = _current().call("card_backs")
	var swatches: Array = [] if row == null else row.call("swatches")
	_expect(swatches.size() == 3, "NO CARD BACK ROW")
	await _shot("settings_card_backs")
	await _click_button_with_text(tr("settings.back"))


## The table at stages 0, 3, 6 and 9, each from a profile handed that corruption and read
## the way a run's start reads it, with no stage override.
func _corruption_frames(profile: SaveService) -> void:
	var saves: Object = tree.root.get_node("Saves").call("run_service")
	for value: int in CORRUPTION_VALUES:
		var data: ProfileData = ProfileData.new()
		data.corruption = value
		Profile.write(profile, data)
		saves.call("delete")
		app.call("show_screen", "title", true)
		await _frames(10)
		_expect(bool(app.call("new_run", SEED + value)), "NO RUN AT CORRUPTION %d" % value)
		app.call("show_screen", "table", true)
		await _frames(30)
		var stage: int = ArtStages.stage()
		var wanted: int = ArtStages.stage_of(value)
		_expect(stage == wanted, "STAGE %d AT CORRUPTION %d" % [stage, value])
		await _shot("table_corruption_%02d" % value)
	saves.call("delete")


## The profile's files as they are, to put back after the sandbox; a missing file is kept
## as missing.
func _keep_files(profile: SaveService) -> Dictionary[String, String]:
	var kept: Dictionary[String, String] = {}
	var path: String = profile.path()
	for file: String in [path, path + SaveService.BACKUP_SUFFIX]:
		kept[file] = FileAccess.get_file_as_string(file) if FileAccess.file_exists(file) else ""
	return kept


func _put_back_files(kept: Dictionary[String, String]) -> void:
	for file: String in kept:
		if kept[file].is_empty():
			DirAccess.remove_absolute(file)
		elif not ToolFiles.write(file, kept[file]):
			_fail("PROFILE FILE %s NOT PUT BACK" % file)


## The table's menu, Abandon run, and its question, then Abandon: the title, with no save.
func _abandon_frames(table: Node, saves: Object) -> void:
	var hud: Object = member(table, "hud")
	await _press(hud.get("menu"))
	await _frames(20)
	var pause: Node = member(table, "pause")
	await _press_text_in(pause, tr("menu.abandon"))
	await _frames(20)
	await _shot("pause_abandon_confirm")
	var keep: Button = pause.call("keep_button")
	_expect(bool(pause.call("is_confirming")) and keep.has_focus(), "ABANDON FOCUS WRONG")
	await _press(pause.call("abandon_button"))
	await _frames(30)
	if _screen_id() != "title":
		_misclick("Abandon did not go home")
	_expect(not FileAccess.file_exists(str(saves.call("path"))), "ABANDON KEPT THE SAVE")


## Saves a run finished as outcome and continues it, which opens its ending.
func _open_ending(outcome: String, saves: Object) -> Node:
	var record: RunRecord = RunRecord.new()
	record.mark(_finished_run(ENDING_RUNS[outcome]))
	saves.call("save", record.to_dict(), ContentStamp.extras())
	app.call("resume_to_screen")
	await _frames(20)
	if _screen_id() != "ending":
		_fail("NO ENDING SCREEN FOR %s" % outcome)
	return _current()


## A run at its end with the given meters, Resentment and rounds as landlord, and every
## family of the village: some warm, some wary, some bitter, one in reeducation, one
## deposed and two dead.
func _finished_run(values: Array) -> RunState:
	var state: RunState = RunState.new(SEED)
	state.phase = RunFlow.State.RUN_END
	state.year = 8
	state.famine = values[0]
	state.denunciation = values[1]
	state.resentment = values[2]
	state.year_rounds = 4
	state.year_landlord_rounds = values[3]
	for family: FamilyDef in RunDefaults.VILLAGE.families:
		state.roster.append(RosterEntry.new(family.id))
	state.roster[1].status = RosterEntry.Status.REEDUCATION
	state.roster[4].status = RosterEntry.Status.DEPOSED
	state.roster[6].status = RosterEntry.Status.DEAD
	state.roster[11].status = RosterEntry.Status.DEAD
	var summary: SetSummary = SetSummary.new(0)
	for warm: int in [0, 5, 9]:
		summary.add(state.roster[warm].family_id, SetSummary.Kind.FED, 4)
	for bitter: int in [2, 8, 12]:
		summary.add(state.roster[bitter].family_id, SetSummary.Kind.DENOUNCED, 3)
	summary.add(state.roster[3].family_id, SetSummary.Kind.BOMBED, 1)
	state.memory.record(summary)
	return state


## Presses Enter, as any accept press shows the whole epilogue, and checks that it did.
## A page without an epilogue, or one already whole, is left alone: there Enter would
## press Return to title.
func _accept_epilogue(screen: Node) -> void:
	if screen.call("epilogue") == null or not bool(screen.call("is_revealing")):
		return
	await _press_key(KEY_ENTER)
	var epilogue: Object = screen.call("epilogue")
	var lines: Array = epilogue.call("line_labels")
	if bool(screen.call("is_revealing")) or int(epilogue.call("shown_count")) != lines.size():
		_misclick("Enter did not show the epilogue whole")
