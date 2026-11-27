# gdlint: disable=max-public-methods,max-file-lines
# Over 20 public methods and 400 lines: the UI's one command surface, each command sent
# through _act, and the lifecycle and searches of the run it serves.
class_name RunController
extends Node
## The one way the UI touches a run. It owns the run loop and its state, takes the UI's
## commands, and re-emits the loop's domain events as signals. What a screen reads of the
## run it reads through the views built over each run: run, texts, figures, table, items,
## store and seats, which hand out copies, so a screen can read the run but never change
## it. With a save service it saves after every state boundary and every command, so
## quitting at any moment loses nothing.

## Emitted for each domain event the loop makes, in order; views render it.
signal event_emitted(event: RunEvent)
## The loop now waits on this value, one of the AWAIT constants.
signal awaiting_changed(awaiting: int)
## A command the loop refused, with its reason.
signal command_refused(command: String, reason: int)

## The run waits on the player's bid. This and the AWAIT_ constants below are what the run
## waits on, for views that may not name the loop.
const AWAIT_BID: int = RunLoop.Awaiting.PLAYER_BID
## The run waits on the player to swap plot cards or go on.
const AWAIT_SWAP: int = RunLoop.Awaiting.PLAYER_SWAP
## The run waits on the player to play or pass.
const AWAIT_PLAY: int = RunLoop.Awaiting.PLAYER_PLAY
## The run waits on the player to declare their need from the Commons.
const AWAIT_NEED: int = RunLoop.Awaiting.PLAYER_NEED
## The Set is over; the run waits on the player to leave it for the store or the next Set.
const AWAIT_SET_OVER: int = RunLoop.Awaiting.SET_OVER
## The run waits on the player in the shops after a Set.
const AWAIT_STORE: int = RunLoop.Awaiting.SHOP
## The run has ended and waits only for its ending to be shown.
const AWAIT_RUN_OVER: int = RunLoop.Awaiting.RUN_OVER
## The run waits on the player in the re-education that follows a Set when it is owed.
const AWAIT_REEDUCATION: int = RunLoop.Awaiting.REEDUCATION
## A peasant player may use a Campaign before the first play, then play on.
const AWAIT_OPENING: int = RunLoop.Awaiting.PLAYER_OPENING
## A villager's play is being searched (ADR 0030): nothing to do but wait for it.
const AWAIT_VILLAGER: int = RunLoop.Awaiting.VILLAGER_SEARCH
## A Campaign that can be used now (CampaignEffect.Reason.OK).
const CAMPAIGN_OK: int = CampaignEffect.Reason.OK
## The envelope pick that keeps nothing.
const TAKE_NOTHING: int = EnvelopeCounter.NOTHING
## An envelope pick that names no deck card to take out.
const NO_CARD: int = Deck.NO_SLOT
## The reason a command carries when the loop accepted it.
const OK: int = RunLoop.Reason.OK

## True while the run's searching villagers decide under the ExpertRunner's deadline, as
## the live game plays (ADR 0030). In the tree the loop then stands still while one
## thinks, and the search runs on the worker pool while frames go on (ADR 0030); outside it
## each is searched at once on the calling thread. A tool or test that must stay
## repeatable sets it false before it starts or resumes a run, and they search with no
## limit inside the loop.
var live_search: bool = true
## Weights a searching villager decides with in place of its own, so a tool can sample
## fewer deals (ADR 0027); null for its own.
var search_weights: BotWeights = null
## The file's three detectors (ADR 0022). A test may turn acting on, or take the line a
## mismatch logs, through it.
var file_watch: FileWatch = FileWatch.new()

## The run's state as a screen reads it (null with no run, as every view is).
var run: RunView
## What the run's items and rules say.
var texts: RunTexts
## The run's numbers as its rules set them.
var figures: RunFigures
## The round in play as the player sees it.
var table: RunTableView
## What the player holds and what is in force.
var items: RunItemsView
## The shops this visit.
var store: RunStoreView
## Who sits at the table.
var seats: RunSeatsView

var _loop: RunLoop
## Decides for the loop's searcher, and for a villager answered at once outside the tree.
## Every decision blocks until its samples finish.
var _runner: ExpertRunner = ExpertRunner.new()
## The searches run on the pool for villagers the loop stands still for (ADR 0030).
var _searches: VillagerSearches = VillagerSearches.new()
var _saves: SaveService = null
## The profile save, which the village's memory outlives runs in.
var _profile: SaveService = null
## True while the profile lacks something the run has reached, since its write failed.
var _profile_owed: bool = false


## Starts a new run from seed, with one bot config per seat. It begins as a demo run
## through RunStarter, as every run does; tests use it to choose their own seats and Sets.
func start_run(
	seed_value: int,
	configs: Array[BotConfig],
	sets: SetConfig = SetConfig.new(),
	saves: SaveService = null,
	starting_coupons: int = 0,
	profile: SaveService = null
) -> void:
	var request: RunRequest = RunRequest.new(RunRequest.DEMO, seed_value)
	request.writes_profile = profile != null
	var state: RunState = RunStarter.state(request, profile)
	state.coupons = starting_coupons
	_begin(state, configs, sets, saves, profile)


## Starts the run a request asks for, with the Sets and seats of its kind (ADR 0025).
## The profile is written only when the request allows it. False, with nothing started,
## for a household or stake the profile has not unlocked.
func start(request: RunRequest, saves: SaveService = null, profile: SaveService = null) -> bool:
	var used: SaveService = profile if request.writes_profile else null
	var state: RunState = RunStarter.state(request, used)
	if state == null:
		return false
	var kind: RunIdentity.Kind = request.kind
	_begin(state, RunStarter.configs(), RunStarter.sets(kind), saves, used)
	return true


func _begin(
	state: RunState,
	configs: Array[BotConfig],
	sets: SetConfig,
	saves: SaveService,
	profile: SaveService
) -> void:
	_profile = profile
	_profile_owed = false
	file_watch.attach(saves, profile)
	_attach(RunLoop.new(state, configs, sets), saves)
	_loop.start_set()
	_serve()
	file_watch.started(_loop)
	_loop.set_log.flush()
	awaiting_changed.emit(_loop.awaiting())


## For tests: takes over a loop built outside the controller, as resume_saved() takes
## over one replayed from a save, so a test can set up a run state no save would reach.
func resume(loop: RunLoop, saves: SaveService = null, profile: SaveService = null) -> void:
	_take_over(loop, saves, profile, null)


## Takes over a loop resumed from a save, with what the load found, which the file's
## detectors act on: a seal that failed, or a ledger the save does not hold (ADR 0022). A
## save written just before a crash may stand past a boundary the profile never took, so
## the profile is offered it again; it takes nothing twice.
func _take_over(loop: RunLoop, saves: SaveService, profile: SaveService, loaded: SaveLoad) -> void:
	_profile = profile
	_profile_owed = false
	file_watch.attach(saves, profile)
	_attach(loop, saves)
	if file_watch.resumed(_loop, loaded):
		_save()
	# A save written while a villager thought resumes standing still for it (ADR 0030).
	if _serve():
		_save()
	_remember(_loop.flow.state())
	file_watch.sealed(_loop)
	_loop.set_log.flush()
	awaiting_changed.emit(_loop.awaiting())


## Continues the saved run as the kind it was saved as, with that kind's Sets and seats.
## False when neither the save nor its backup loads.
func continue_saved(saves: SaveService, profile: SaveService = null) -> bool:
	var loaded: SaveLoad = saves.load_save()
	if (
		loaded.status != SaveLoad.Status.OK
		and loaded.status != SaveLoad.Status.RESTORED_FROM_BACKUP
	):
		return false
	var kind: RunIdentity.Kind = RunStarter.saved_kind(loaded.data)
	return resume_saved(saves, RunStarter.configs(), RunStarter.sets(kind), profile)


## Resumes the run in the save, falling back to its backup. False when neither loads.
## A save written against other content, or whose commands no longer apply, resumes at
## its checkpoint, the start of its Quota (ADR 0033).
func resume_saved(
	saves: SaveService, configs: Array[BotConfig], sets: SetConfig, profile: SaveService = null
) -> bool:
	var loaded: SaveLoad = saves.load_save()
	if (
		loaded.status != SaveLoad.Status.OK
		and loaded.status != SaveLoad.Status.RESTORED_FROM_BACKUP
	):
		return false
	var data: Dictionary = loaded.data
	if not ContentStamp.matches(loaded.extras):
		data = ContentStamp.at_checkpoint(data)
	var loop: RunLoop = _resumed(data, configs, sets)
	if loop == null:
		loop = _resumed(ContentStamp.at_checkpoint(data), configs, sets)
	if loop == null:
		return false
	_take_over(loop, saves, profile, loaded)
	return true


## The save's run replayed, with searches answered from outside when this controller
## searches live, so a villager the record ends before is searched again, not here.
func _resumed(data: Dictionary, configs: Array[BotConfig], sets: SetConfig) -> RunLoop:
	var params: RunParams = RunDefaults.PARAMS
	var pool: Array[ModifierDef] = RunPools.DEBUFFS.debuffs
	var meters: MeterTable = RunDefaults.METERS
	var searcher: Callable = Callable()
	return RunRecord.resume(
		data, configs, sets, params, pool, meters, searcher, live_search, search_weights
	)


## True while the controller holds a run.
func has_run() -> bool:
	return _loop != null


## True when the profile holds everything the run has reached. After a write of it that
## failed, the write is tried again first while the run stands at a Set's end or its own,
## where what the profile takes is whole; elsewhere the next Set's end carries it.
func is_profile_whole() -> bool:
	if _profile_owed and _loop != null:
		_remember(_loop.flow.state())
	return not _profile_owed


## Calls or grabs the landlord seat with claim true, or passes on it.
func bid(claim: bool) -> int:
	return _act("bid", _loop.player_bid.bind(claim))


## Brings plot cards into the hand in place of hand cards, one for one (ADR 0038).
func swap(hand_ids: Array[int], plot_ids: Array[int]) -> int:
	return _act("swap", _loop.player_swap.bind(hand_ids.duplicate(), plot_ids.duplicate()))


## reading names how the cards are read, one of readings_for(); with none, the strongest
## reading stands, so a play that could read more than one way is played as the
## strongest until the reading picker passes one (ADR 0029).
func play(card_ids: Array[int], reading: Pattern = null) -> int:
	var chosen: Pattern = null if reading == null else reading.copy()
	return _act("play", _loop.player_play.bind(card_ids.duplicate(), chosen))


## Passes the player's turn.
func pass_turn() -> int:
	var none: Array[int] = []
	return _act("pass", _loop.player_play.bind(none))


## Declares the player's need from the Commons at the split.
func declare_need(need: int) -> int:
	return _act("declare_need", _loop.player_need.bind(need))


## Moves past a finished Set: into the state store, or past the run's last Set to its end.
func finish_set() -> int:
	if is_last_set():
		return _act("finish_set", _loop.next_set)
	return _act("finish_set", _loop.open_shop)


## Buys the state store's Cadre in slot.
func buy(slot: int) -> int:
	return _act("buy", _loop.player_buy.bind(slot))


## Rerolls the state store's Cadres.
func reroll() -> int:
	return _act("reroll", _loop.player_reroll)


## Buys from the black market, which adds Resentment. A Cadre that needs a rank is
## refused without one (Ranks.THREE to Ranks.TWO).
func market_buy(slot: int, rank: int = Ranks.INVALID) -> int:
	return _act("market_buy", _loop.player_market_buy.bind(slot, rank))


## Rerolls the black market's Cadres.
func market_reroll() -> int:
	return _act("market_reroll", _loop.player_market_reroll)


## Buys one step of a private-plot upgrade at the black market.
func upgrade(kind: String) -> int:
	return _act("upgrade", _loop.player_upgrade.bind(kind))


## Buys a card for the private plot at the black market.
func plot_card(slot: int) -> int:
	return _act("plot_card", _loop.player_plot_card.bind(slot))


## Issues a Directive from the state store: its hand types rise a level at once.
func directive(slot: int) -> int:
	return _act("directive", _loop.player_directive.bind(slot))


## Uses the held Campaign in slot, on the chosen hand cards when it asks for any.
func campaign(slot: int, card_ids: Array[int] = []) -> int:
	return _act("campaign", _loop.player_campaign.bind(slot, card_ids.duplicate()))


## Leaves the opening, where a Campaign could be used, for the round's first play.
func begin_round() -> int:
	return _act("begin_round", _loop.player_begin)


## Buys the Campaign on the state store's counter, or the black market's.
func campaign_buy(slot: int, market: bool = false) -> int:
	if market:
		return _act("campaign_buy", _loop.player_market_campaign.bind(slot))
	return _act("campaign_buy", _loop.player_campaign_buy.bind(slot))


## Sells the held Cadre at index back to the state store, or the black market, for part
## of its price there (ADR 0040).
func sell_cadre(index: int, market: bool = false) -> int:
	return _act("sell_cadre", _loop.player_sell_cadre.bind(index, market))


## Sells the held Campaign at index back to the state store, or the black market.
func sell_campaign(index: int, market: bool = false) -> int:
	return _act("sell_campaign", _loop.player_sell_campaign.bind(index, market))


## Marks a deck card at the state store's desk, or the black market's, for the rest of
## the run (ADR 0041).
func mark_card(card_id: int, market: bool = false) -> int:
	return _act("mark_card", _loop.player_mark_card.bind(card_id, market))


## Enacts the state store's Reform for the rest of the run (ADR 0021).
func reform(slot: int) -> int:
	return _act("reform", _loop.player_reform.bind(slot))


## Buys the envelope on the state store's counter, or the black market's Parcel, and
## opens it at once (ADR 0021).
func envelope_buy(slot: int, market: bool = false) -> int:
	if market:
		return _act("envelope_buy", _loop.player_market_envelope.bind(slot))
	return _act("envelope_buy", _loop.player_envelope_buy.bind(slot))


## Keeps the open envelope's item at index, or nothing with TAKE_NOTHING. A card for the
## deck goes in place of the deck card in out (ADR 0042).
func envelope_pick(index: int, out: int = NO_CARD) -> int:
	return _act("envelope_pick", _loop.player_envelope_pick.bind(index, out))


## Buys the state store's card in slot for the communal deck, in place of the deck card
## in out, for the rest of the run (ADR 0042). It is the loop's player_deck_card(), so a
## refusal names the command as the record does: deck_card.
func exchange_card(slot: int, out: int) -> int:
	return _act("deck_card", _loop.player_deck_card.bind(slot, out))


## Leaves the store for the next Set, or the run's end.
func leave_store() -> int:
	return _act("leave_store", _loop.leave_store)


## Returns from reeducation to the next Set, or the run's end.
func leave_reeducation() -> int:
	return _act("leave_reeducation", _loop.leave_reeducation)


## What the run waits on now, one of the AWAIT constants.
func awaiting() -> int:
	return _loop.awaiting()


## True while the Set in play, or the one just ended, is the run's last.
func is_last_set() -> bool:
	return _loop.is_last_set()


## The current Set's events so far, for a view that joins mid-Set.
func set_events() -> Array[RunEvent]:
	return _loop.events().duplicate()


## Lets the run go, as when the arrival ends: no save or profile is touched.
func drop() -> void:
	_searches.let_go()
	_loop = null
	run = null
	texts = null
	figures = null
	table = null
	items = null
	store = null
	seats = null
	_profile_owed = false
	file_watch.dropped()


## Takes figures reported from outside the game as official (ADR 0022), by
## RunCorrections' names. The file's detectors send it; it is a command like any other.
func books(reported: Dictionary) -> int:
	return _act("books", _loop.player_books.bind(reported.duplicate()))


## For development tools and tests only: after changing the run's figures directly, tells
## the second book the change was meant, so the next command compares against it.
func reseal_book() -> void:
	if _loop != null:
		file_watch.sealed(_loop)


## A whole copy of the run state, for tests and development tools that change or keep
## one. The UI may not call it: a screen reads the run through run and the other views,
## and the UI boundary check holds it to that.
func state_copy() -> RunState:
	return RunState.from_dict(_loop.state.to_dict())


## The run's loop itself, for tests and development tools that set up or read what no
## command reaches. The UI may not call it: it reaches a run only through commands and
## queries, and the UI boundary check holds it to that.
func run_loop() -> RunLoop:
	return _loop


func _attach(loop: RunLoop, saves: SaveService) -> void:
	# A search still running for the loop this one replaces is thrown away when it ends.
	_searches.let_go()
	_loop = loop
	_loop.decisions.searcher = _runner.search if live_search else Callable()
	_loop.decisions.answered_outside = live_search
	_loop.decisions.weights = search_weights
	# A replayed loop may hold events banking appended unseen; the view reads those from
	# set_events(), so the listener starts after them.
	_loop.set_log.flush()
	_saves = saves
	run = RunView.new(loop.state)
	texts = RunTexts.new(loop)
	figures = RunFigures.new(loop)
	table = RunTableView.new(loop)
	items = RunItemsView.new(loop)
	store = RunStoreView.new(loop)
	seats = RunSeatsView.new(loop)
	_latch_stage()
	_loop.set_log.on_add = func(event: RunEvent) -> void:
		# The art's stage is read from the profile at each round's start, before the table
		# hears of it, and never inside a round (ADR 0025).
		if event.type == RunEvent.Type.SET_STARTED or event.type == RunEvent.Type.DEALT:
			_latch_stage()
		event_emitted.emit(event)
	_loop.on_boundary = func(at: RunLoop) -> void:
		_save()
		_remember(at.flow.state())


func _latch_stage() -> void:
	if _profile != null:
		ArtStages.latch(_profile)


## Handles one command: the file's detectors look first, and what they correct is saved
## before the command goes on (ADR 0022).
func _act(command: String, act: Callable) -> int:
	# A search let go of when the controller left the tree is made now, before the command.
	if not is_inside_tree():
		settle_search()
	if file_watch.check(_loop):
		_save()
	return _finish(command, act.call())


func _finish(command: String, reason: RunLoop.Reason) -> int:
	if reason == RunLoop.Reason.OK:
		_serve()
	_loop.set_log.flush()
	if reason != RunLoop.Reason.OK:
		command_refused.emit(command, reason)
	else:
		_save()
		awaiting_changed.emit(_loop.awaiting())
	file_watch.sealed(_loop)
	return reason


## Hands in a searched villager's play when its search on the pool has finished, and
## starts the search for a villager the loop stands still for if none runs (ADR 0030).
func _process(_delta: float) -> void:
	var decided: BotPlay = _searches.poll(_loop)
	if decided != null:
		_hand_in(decided)
	elif _awaits_villager():
		_searches.serve(_loop)


## Nothing polls a search once the controller leaves the tree, so every one is stopped
## and waited for, and its play thrown away. The loop still stands still for the villager:
## back in the tree its search starts again, and outside it is made at the next command.
func _exit_tree() -> void:
	_searches.wait_all()


## For tools and tests that drive a run without frames: waits for the play of the villager
## the loop stands still for, on this thread, and hands it in, as frames would.
func settle_search() -> void:
	if not _awaits_villager():
		return
	var decided: BotPlay = _searches.wait(_loop)
	if decided == null:
		decided = _search_now()
	_hand_in(decided)


## Searches still running on the pool, for tests: one for the villager awaited now, and
## any let go of that have yet to finish.
func searches_running() -> int:
	return _searches.running()


func _awaits_villager() -> bool:
	return _loop != null and _loop.awaiting() == RunLoop.Awaiting.VILLAGER_SEARCH


## Answers a villager the loop stands still for (ADR 0030). In the tree its search starts on
## the pool and _process hands the play in. Outside it, as for a caller that never runs
## frames, each such villager is searched at once on this thread. True when plays went
## in here.
func _serve() -> bool:
	if not _awaits_villager():
		return false
	if is_inside_tree():
		_searches.serve(_loop)
		return false
	while _awaits_villager():
		var reason: RunLoop.Reason = _loop.villager_play(_search_now())
		assert(reason == RunLoop.Reason.OK, "The loop refused the play it stood still for")
	return true


func _search_now() -> BotPlay:
	var request: SearchRequest = _loop.search_request()
	return _runner.search(request.view, request.legal, request.table, request.config)


## A searched play goes in as a command's result does: its events out, the run saved,
## and the second book sealed again over the figures the play changed, since a play can
## end a round and bank Grain, before anyone is told what the run waits on now.
func _hand_in(decided: BotPlay) -> void:
	var reason: RunLoop.Reason = _loop.villager_play(decided)
	assert(reason == RunLoop.Reason.OK, "The loop refused the play it stood still for")
	_serve()
	_loop.set_log.flush()
	_save()
	file_watch.sealed(_loop)
	awaiting_changed.emit(_loop.awaiting())


## Writes the run save, with the ledger's numbers and the content's stamp (ADR 0033)
## beside it under the seal, then the ledger itself once the save is whole (ADR 0022).
func _save() -> void:
	if _saves == null:
		return
	var extras: Dictionary = file_watch.before_write(_loop.state.coupons)
	extras[ContentStamp.KEY] = ContentStamp.current()
	if _saves.save(_loop.record.to_dict(), extras) == Error.OK:
		file_watch.written(extras)


## Writes the village's memory to the profile once a Set's summary is folded in, so it
## survives the run whether it ends or is abandoned, and at the run's end its record.
## ProfileCommits takes each only once. A write that fails leaves the profile owed what
## the run has reached, until a later one takes it.
func _remember(at: RunFlow.State) -> void:
	if _profile == null:
		return
	if at == RunFlow.State.SET_END or at == RunFlow.State.RUN_END:
		var finished: bool = at == RunFlow.State.RUN_END
		_profile_owed = ProfileCommits.commit(_profile, _loop.state, finished) != Error.OK
