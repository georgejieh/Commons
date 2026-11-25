# gdlint: disable=max-public-methods,max-file-lines
# Over 20 public methods and 400 lines: this is the UI's whole command and query surface,
# kept in one place.
class_name RunController
extends Node
## The one way the UI touches a run. It owns the run loop and its state, takes the UI's
## commands, and re-emits the loop's domain events as signals. Queries hand out copies,
## so a view can read the run but never change it. With a save service it saves after
## every state boundary and every command, so quitting at any moment loses nothing.

signal event_emitted(event: RunEvent)
## The loop now waits on this value, one of the AWAIT constants.
signal awaiting_changed(awaiting: int)
## A command the loop refused, with its reason.
signal command_refused(command: String, reason: int)

## Every command the UI may send. Selection is the hand model's, not the run's.
const COMMANDS: Array[String] = [
	"bid",
	"swap",
	"play",
	"pass",
	"declare_need",
	"finish_set",
	"buy",
	"reroll",
	"market_buy",
	"market_reroll",
	"upgrade",
	"plot_card",
	"directive",
	"campaign",
	"begin_round",
	"campaign_buy",
	"reform",
	"envelope_buy",
	"envelope_pick",
	"leave_store",
	"books",
	"sell_cadre",
	"sell_campaign",
]
## What the run waits on, for views that may not name the loop.
const AWAIT_BID: int = RunLoop.Awaiting.PLAYER_BID
const AWAIT_SWAP: int = RunLoop.Awaiting.PLAYER_SWAP
const AWAIT_PLAY: int = RunLoop.Awaiting.PLAYER_PLAY
const AWAIT_NEED: int = RunLoop.Awaiting.PLAYER_NEED
const AWAIT_SET_OVER: int = RunLoop.Awaiting.SET_OVER
const AWAIT_STORE: int = RunLoop.Awaiting.SHOP
const AWAIT_RUN_OVER: int = RunLoop.Awaiting.RUN_OVER
const AWAIT_REEDUCATION: int = RunLoop.Awaiting.REEDUCATION
const AWAIT_OPENING: int = RunLoop.Awaiting.PLAYER_OPENING
## A villager's play is being searched (P5.0): nothing to do but wait for it.
const AWAIT_VILLAGER: int = RunLoop.Awaiting.VILLAGER_SEARCH
## A Campaign that can be used now (CampaignEffect.Reason.OK).
const CAMPAIGN_OK: int = CampaignEffect.Reason.OK
## The envelope pick that keeps nothing.
const TAKE_NOTHING: int = EnvelopeCounter.NOTHING
## Suit names in suit order: spade, heart, club, diamond.
const SUIT_KEYS: Array[String] = ["suit.spades", "suit.hearts", "suit.clubs", "suit.diamonds"]
const OK: int = RunLoop.Reason.OK

## True while the run's searching villagers decide under the ExpertRunner's deadline, as
## the live game plays (ADR 0030). In the tree the loop then stands still while one
## thinks, and the search runs on the worker pool while frames go on (P5.0); outside it
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

var _loop: RunLoop
## Decides for the loop's searcher, and for a villager answered at once outside the tree.
## Every decision blocks until its samples finish.
var _runner: ExpertRunner = ExpertRunner.new()
## The searches run on the pool for villagers the loop stands still for (P5.0).
var _searches: VillagerSearches = VillagerSearches.new()
var _saves: SaveService = null
## The profile save, which the village's memory outlives runs in (P4.6).
var _profile: SaveService = null
var _definitions: Dictionary[String, ModifierDef] = {}
var _directives: Dictionary[String, DirectiveDef] = {}


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
	var kind: int = request.kind
	_begin(state, RunStarter.configs(kind), RunStarter.sets(kind), saves, used)
	return true


func _begin(
	state: RunState,
	configs: Array[BotConfig],
	sets: SetConfig,
	saves: SaveService,
	profile: SaveService
) -> void:
	_profile = profile
	file_watch.attach(saves, profile)
	_attach(RunLoop.new(state, configs, sets), saves)
	_loop.start_set()
	_serve()
	file_watch.started(_loop)
	_loop.set_log.flush()
	awaiting_changed.emit(_loop.awaiting())


## Takes over a loop that was resumed from a save. A save written just before a crash
## may stand past a boundary the profile never took, so the profile is offered it again;
## it takes nothing twice.
func resume(loop: RunLoop, saves: SaveService = null, profile: SaveService = null) -> void:
	_take_over(loop, saves, profile, null)


## What resume() does, with what the load found, which the file's detectors act on: a
## seal that failed, or a ledger the save does not hold (ADR 0022).
func _take_over(loop: RunLoop, saves: SaveService, profile: SaveService, loaded: SaveLoad) -> void:
	_profile = profile
	file_watch.attach(saves, profile)
	_attach(loop, saves)
	if file_watch.resumed(_loop, loaded):
		_save()
	# A save written while a villager thought resumes standing still for it (P5.0).
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
	var kind: int = RunStarter.saved_kind(loaded.data)
	return resume_saved(saves, RunStarter.configs(kind), RunStarter.sets(kind), profile)


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
	var params: RunParams = RunLoop.DEFAULT_PARAMS
	var pool: Array[ModifierDef] = RunLoop.DEFAULT_POOL.debuffs
	var meters: MeterTable = RunLoop.DEFAULT_METERS
	return RunRecord.resume(data, configs, sets, params, pool, meters, Callable(), live_search)


func has_run() -> bool:
	return _loop != null


## The seat that has called or grabbed the landlord seat in the bidding under way, or
## Seats.NONE while nobody has, or outside bidding.
func bid_holder() -> int:
	return _loop.bid_holder()


func bid(claim: bool) -> int:
	return _act("bid", _loop.player_bid.bind(claim))


## The most cards the player may swap this round (P4.8).
func swap_limit() -> int:
	return _loop.swap_limit()


func swap(hand_ids: Array[int], plot_ids: Array[int]) -> int:
	return _act("swap", _loop.player_swap.bind(hand_ids.duplicate(), plot_ids.duplicate()))


## reading names how the cards are read, one of readings_for(); with none, the strongest
## reading stands, so a play that could read more than one way is played as the
## strongest until the reading picker passes one (ADR 0029).
func play(card_ids: Array[int], reading: Pattern = null) -> int:
	var chosen: Pattern = null if reading == null else reading.copy()
	return _act("play", _loop.player_play.bind(card_ids.duplicate(), chosen))


func pass_turn() -> int:
	var none: Array[int] = []
	return _act("pass", _loop.player_play.bind(none))


func declare_need(need: int) -> int:
	return _act("declare_need", _loop.player_need.bind(need))


## Moves past a finished Set: into the state store, or past the run's last Set to its end.
func finish_set() -> int:
	if is_last_set():
		return _act("finish_set", _loop.next_set)
	return _act("finish_set", _loop.open_shop)


func buy(slot: int) -> int:
	return _act("buy", _loop.player_buy.bind(slot))


func reroll() -> int:
	return _act("reroll", _loop.player_reroll)


## Buys from the black market, which adds Resentment. A Cadre that needs a rank is
## refused without one (Ranks.THREE to Ranks.TWO).
func market_buy(slot: int, rank: int = Ranks.INVALID) -> int:
	return _act("market_buy", _loop.player_market_buy.bind(slot, rank))


## True when buying the Cadre asks for a rank first (ADR 0021).
func needs_rank(cadre_id: String) -> bool:
	return _definitions.has(cadre_id) and _definitions[cadre_id].needs_rank


## Where a held Cadre stands in the run: its state line and badge count, both empty when
## it keeps no state or is not held.
func cadre_standing(cadre_id: String) -> CadreStanding:
	var state: RunState = _loop.state
	if not _definitions.has(cadre_id) or not state.inventory.cadres.has(cadre_id):
		return CadreStanding.new()
	return CadreStanding.of(_definitions[cadre_id], state.cadre_memos.peek(cadre_id))


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


## A Directive's name and rules, and the hand types it raises, as Pattern.Type values.
func directive_name(directive_id: String) -> String:
	return tr(_directives[directive_id].name_key)


func directive_text(directive_id: String) -> String:
	return tr(_directives[directive_id].text_key)


func directive_types(directive_id: String) -> Array[int]:
	return _directives[directive_id].hand_types.duplicate()


## A hand type's level in this run, and its Rate at a level, from the scorer's table.
func hand_level(type: int) -> int:
	return _loop.state.hand_levels.level_of(type as Pattern.Type)


func hand_rate(type: int, level: int) -> int:
	return Scorer.DEFAULT_PARAMS.rate_for(type, level)


func max_hand_level() -> int:
	return Scorer.DEFAULT_PARAMS.max_level


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


## The Campaigns the player holds, in slot order, and how many they can hold.
func held_campaigns() -> Array[String]:
	return _loop.state.inventory.consumables.duplicate()


func campaign_slots() -> int:
	return RunReforms.campaign_slots(_loop.state)


## Why the held Campaign in slot cannot be used now, as a CampaignEffect.Reason, or
## CAMPAIGN_OK. With check_cards false the chosen cards are left aside.
func campaign_reason(slot: int, card_ids: Array[int] = [], check_cards: bool = false) -> int:
	return _loop.campaign_reason(slot, card_ids.duplicate(), check_cards)


## The string key that says why a Campaign is refused, one per reason.
static func campaign_reason_key(reason: int) -> String:
	return "campaign.reason." + String(CampaignEffect.Reason.keys()[reason]).to_lower()


## A Campaign's name, rules, prompt and card counts, with its numbers filled in.
func campaign_name(campaign_id: String) -> String:
	return tr(_campaign(campaign_id).name_key)


func campaign_text(campaign_id: String) -> String:
	var definition: CampaignDef = _campaign(campaign_id)
	return tr(definition.text_key).format(definition.text_values())


func campaign_prompt(campaign_id: String) -> String:
	var definition: CampaignDef = _campaign(campaign_id)
	return tr(definition.prompt_key).format(definition.text_values())


## Every Campaign's prompt, held or not, and every surname a seat can show, for the
## table's pieces that must have room for the longest (ADR 0034).
func every_campaign_prompt() -> Array[String]:
	var prompts: Array[String] = []
	for pool: CampaignPool in [RunPools.STORE_CAMPAIGNS, RunPools.MARKET_CAMPAIGNS]:
		for definition: CampaignDef in pool.campaigns:
			prompts.append(tr(definition.prompt_key).format(definition.text_values()))
	return prompts


func every_surname() -> Array[String]:
	return RunPeople.every_surname()


## The fewest and most hand cards a Campaign asks for, as x and y.
func campaign_cards(campaign_id: String) -> Vector2i:
	var definition: CampaignDef = _campaign(campaign_id)
	return Vector2i(definition.min_cards, definition.max_cards)


## One of a Campaign's numbers from its data, or 0.
func campaign_parameter(campaign_id: String, key: String) -> int:
	return _campaign(campaign_id).parameters.get(key, 0)


func is_private_campaign(campaign_id: String) -> bool:
	return _campaign(campaign_id).tag == ModifierDef.Tag.PRIVATE


## The debuff Appeal lifted this round, or an empty ID.
func lifted_debuff() -> String:
	return _loop.campaigns.flags.lifted


## The Campaigns on the state store's counter, or the black market's.
func campaign_shelf(market: bool) -> CampaignShelf:
	return CampaignShelf.new(_loop.market.campaigns if market else _loop.shop.campaigns)


## Enacts the state store's Reform for the rest of the run (ADR 0021).
func reform(slot: int) -> int:
	return _act("reform", _loop.player_reform.bind(slot))


## The Reform on the state store's counter, for a screen to read.
func reform_shelf() -> ReformShelf:
	return ReformShelf.new(_loop.shop.reforms)


## Buys the envelope on the state store's counter, or the black market's Parcel, and
## opens it at once (ADR 0021).
func envelope_buy(slot: int, market: bool = false) -> int:
	if market:
		return _act("envelope_buy", _loop.player_market_envelope.bind(slot))
	return _act("envelope_buy", _loop.player_envelope_buy.bind(slot))


## Keeps the open envelope's item at index, or nothing with TAKE_NOTHING.
func envelope_pick(index: int) -> int:
	return _act("envelope_pick", _loop.player_envelope_pick.bind(index))


## The envelope on the state store's counter, or the black market's, for a screen to read.
func envelope_shelf(market: bool) -> EnvelopeShelf:
	var counter: RunShop = _loop.market if market else _loop.shop
	return EnvelopeShelf.new(counter.envelopes, RunLoop.PLAYER, market)


## The shelf whose envelope is open now, or null when none is.
func opened_envelope() -> EnvelopeShelf:
	for market: bool in [false, true]:
		var shelf: EnvelopeShelf = envelope_shelf(market)
		if shelf.is_open():
			return shelf
	return null


## A plot card's name, "7 of Hearts", and what a card from an envelope is: its name, text
## or caption by key, with its mark's numbers from data. kind is one of EnvelopeShelf's
## card kinds.
func card_name(card: CardInstance) -> String:
	var rank: String = tr(Ranks.label_key(card.base_rank()))
	var suit: String = tr(SUIT_KEYS[card.suit()])
	return tr("card.name").format({"rank": rank, "suit": suit})


func envelope_card_text(kind: int, key: String, card: CardInstance) -> String:
	var mark: String = "stamped" if kind == EnvelopeShelf.KIND_STAMPED else "model"
	var model: float = Scorer.DEFAULT_PARAMS.model_grain_percent / 100.0
	var values: Dictionary[String, Variant] = {
		"resentment": RunLoop.DEFAULT_RESENTMENT.stamped_card,
		"model_times": ModifierDef.multiple(model),
		"card": card_name(card),
	}
	return tr("envelope.card.%s.%s" % [mark, key]).format(values)


## The Reforms in force, in the order they were enacted.
func held_reforms() -> Array[String]:
	return _loop.state.reforms.duplicate()


func reform_name(reform_id: String) -> String:
	return tr(RunReforms.definition(reform_id).name_key)


## A Reform's rules with its numbers filled in, the limits it raises included.
func reform_text(reform_id: String) -> String:
	return ItemText.reform(RunReforms.definition(reform_id))


## The state store's counter, or the black market's, for a screen to read.
func desk(market: bool) -> ShopDesk:
	if market:
		var upgrades: PlotUpgradeParams = RunLoop.DEFAULT_PLOT_UPGRADES
		var at_market: ShopDesk = ShopDesk.new(_loop.market, _loop.state, upgrades, _loop.stall)
		at_market.bound = _loop.debuffs.confiscated_ids()
		return at_market
	var at_store: ShopDesk = ShopDesk.new(_loop.shop, _loop.state)
	at_store.bound = _loop.debuffs.confiscated_ids()
	return at_store


## The Resentment every black market purchase adds.
func purchase_resentment() -> int:
	return RunLoop.DEFAULT_RESENTMENT.private_purchase


## Leaves the store for the next Set, or the run's end.
func leave_store() -> int:
	return _act("leave_store", _loop.next_set)


## Returns from reeducation to the next Set, or the run's end.
func leave_reeducation() -> int:
	return _act("leave_reeducation", _loop.next_set)


func awaiting() -> int:
	return _loop.awaiting()


func is_last_set() -> bool:
	var state: RunState = _loop.state
	return state.set_type == RunState.SetType.BOSS and state.year == _loop.sets().years()


## The store's stock per slot, an empty ID for a sold slot.
func store_stock() -> Array[String]:
	return _loop.shop.stock()


## Coupons the current Set pays when its Quota is met, a Reform's extra included.
func quota_reward() -> int:
	return _loop.sets().reward(_loop.state.set_type) + RunReforms.quota_coupons(_loop.state)


## Overfulfilment steps the Set just finished earned, 0 while a Set is in play.
func over_steps() -> int:
	return _loop.state.over_steps


## The extra coupons those steps paid, on top of quota_reward().
func over_bonus() -> int:
	return _loop.sets().over_bonus(_loop.state.over_steps)


## How far the norm has raised targets this run, in percent of each base target. After a
## Set ends, it already counts that Set's steps, which raise the Quotas to come.
func norm_percent() -> int:
	return _loop.sets().norm_percent(_loop.state.norm_steps)


## How far one step raises the norm, in percent.
func norm_step_percent() -> int:
	return _loop.sets().norm_percent(1)


## How far the Set just finished raised the norm, in percent.
func norm_added_percent() -> int:
	return _loop.sets().norm_percent(_loop.state.over_steps)


## How much Famine a missed Quota adds, after any Reform's relief.
func famine_per_miss() -> int:
	var amount: int = RunLoop.DEFAULT_METERS.source(RunMeters.MISSED_TARGET).amount
	return RunReforms.missed_famine(_loop.state, amount)


## True while high Famine cuts the store's slots.
func is_rationed() -> bool:
	return _loop.state.rationed


## The Famine value rationing must fall below to lift.
func rationing_lifts_below() -> int:
	var bands: MeterBands = RunLoop.DEFAULT_METERS.famine
	return bands.mid - bands.rearm_margin


## Cadres the player can hold at once, Reforms included.
func cadre_slots() -> int:
	return RunReforms.cadre_slots(_loop.state)


## What every villager declares by default, a fair need to start the player's choice.
func base_need() -> int:
	return RunLoop.DEFAULT_PARAMS.base_need


## The Resentment the player's grab of a held landlord seat adds.
func grab_cost() -> int:
	return RunLoop.DEFAULT_RESENTMENT.grab


## The chance, 0 to 1, that each claim on the Commons is audited this round.
func audit_chance() -> float:
	return _loop.audit_chance()


## The Denunciation a lie about need costs when an audit catches it.
func lie_cost() -> int:
	return RunLoop.DEFAULT_METERS.source(RunMeters.CAUGHT_LIE).amount


func can_buy(slot: int) -> bool:
	return _loop.shop.check_buy(slot) == RunShop.Reason.OK


## The current Set's events so far, for a view that joins mid-Set.
func set_events() -> Array[RunEvent]:
	return _loop.events().duplicate()


## The player's seat view of the current round, or null between rounds.
func seat_view() -> SeatView:
	return _loop.player_view()


## Copies of the player's cards.
func player_cards() -> Array[CardInstance]:
	return _loop.player_cards()


## The rules and rank order the player plays under.
func player_table() -> BotTable:
	return _loop.seat_table(RunLoop.PLAYER)


## The legal moves when the player must play, else none.
func legal_moves() -> Array[Pattern]:
	if _loop.awaiting() != RunLoop.Awaiting.PLAYER_PLAY:
		return []
	return _loop.round_state().legal_moves()


## Every reading the player's chosen cards may be played as now, strongest first (ADR
## 0029). More than one only when a wild card is among them; none when the cards form no
## play that may be made now, or between rounds.
func readings_for(card_ids: Array[int]) -> Array[Pattern]:
	var none: Array[Pattern] = []
	if _loop.round_state() == null:
		return none
	var read: PlayReading = _loop.round_state().read_play(RunLoop.PLAYER, card_ids.duplicate())
	var result: Array[Pattern] = []
	for reading: Pattern in read.readings:
		result.append(reading.copy())
	return result


## The player's card IDs for a pattern, by the fixed selection policy.
func card_ids_for(pattern: Pattern) -> Array[int]:
	return _loop.round_state().action_for(pattern).card_ids.duplicate()


## How the player's chosen cards read and what they would score now, or null between
## rounds, as reading when one is named. A preview changes nothing.
func preview_play(card_ids: Array[int], reading: Pattern = null) -> PlayPreview:
	if _loop.round_state() == null:
		return null
	var wanted: Pattern = null if reading == null else reading.copy()
	return _loop.preview_play(card_ids.duplicate(), wanted)


## The ranks wild now (ADR 0029), in the order they were drawn: the player's alone, since
## every item that draws one is the player's (ADR 0039).
func wild_ranks() -> Array[int]:
	return _loop.state.wild_ranks.duplicate()


## True while a bomb may hold five or more cards (Industrialization).
func big_bombs() -> bool:
	return player_table().rules.five_plus_is_bomb()


## The held Reforms that give the player's seat a rule that changes play, such as
## Industrialization, for the rules strip and the Rules sheet.
func table_rule_reforms() -> Array[String]:
	return RunReforms.table_rule_ids(_loop.state)


## The modifiers in play now: Cadres in slot order, then this Set's debuffs so far.
func active_modifier_ids() -> Array[String]:
	var ids: Array[String] = _loop.state.inventory.cadres.duplicate()
	ids.append_array(active_debuff_ids())
	return ids


## This Set's debuffs so far, in the order they arrived.
func active_debuff_ids() -> Array[String]:
	var state: RunState = _loop.state
	var ids: Array[String] = []
	for round_index: int in range(1, mini(state.round_index + 1, state.debuff_ladder.size())):
		if state.debuff_ladder[round_index] != RunState.NO_DEBUFF:
			ids.append(state.debuff_ladder[round_index])
	return ids


## The Set's ladder: one debuff ID per round, round 1 always empty.
func ladder() -> Array[String]:
	return _loop.state.debuff_ladder.duplicate()


## The current Set's boss twist ID, or an empty string outside boss Sets (P4.7).
func boss() -> String:
	return _loop.state.boss_id


## True when a Cadre's scoring also pays on the player's teammate's plays while the player
## is a peasant (ADR 0039). No Cadre changes another seat's rules or ranks.
func counts_for_teammate(modifier_id: String) -> bool:
	var definition: ModifierDef = _definitions[modifier_id]
	return definition.counts_for_teammate


## A modifier's rules text with its parameters filled in.
func modifier_text(modifier_id: String) -> String:
	return CadreText.rules(_definitions[modifier_id], _run_values(modifier_id))


## A modifier's name; a Slogan's names the hand type it was drawn with (ADR 0023).
func modifier_name(modifier_id: String) -> String:
	var type: int = _loop.state.slogan_type
	if modifier_id == RunDebuffs.SLOGAN_ID and type != RunState.NO_SLOGAN:
		return tr("modifier.slogan_of_the_week.named").format({"type": _type_plural(type)})
	return tr(_definitions[modifier_id].name_key)


## Why the player may not pass now, as a string key, or "" when they may (Night Shift).
func pass_refusal() -> String:
	if _loop.awaiting() != RunLoop.Awaiting.PLAYER_PLAY:
		return ""
	var reason: RoundState.Reason = _loop.round_state().pass_reason()
	return "table.must_play" if reason == RoundState.Reason.MUST_PLAY else ""


## The held Cadres a Confiscation left out of this round.
func confiscated_cadres() -> Array[String]:
	return _loop.debuffs.confiscated_ids()


## True while the villagers see the player's hand (Glass Walls).
func hand_shown() -> bool:
	return _loop.round_state() != null and player_table().rules.hand_shown()


## Copies of the plot cards Plot Seized destroyed this round.
func seized_cards() -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for card: CardInstance in _loop.debuffs.seized:
		cards.append(card.snapshot())
	return cards


## Cadres Short Supply keeps off the state store's counter this visit.
func short_supply() -> int:
	return _loop.shop.short_cut


## Values a modifier's text takes from the run: the Slogan's hand type, and the meter rise
## a lost round costs.
func _run_values(modifier_id: String) -> Dictionary[String, Variant]:
	var values: Dictionary[String, Variant] = {}
	if modifier_id == RunDebuffs.SLOGAN_ID:
		var type: int = _loop.state.slogan_type
		values["type"] = (
			tr("modifier.slogan_of_the_week.no_type")
			if type == RunState.NO_SLOGAN
			else _type_plural(type)
		)
	var effect: ModifierEffect = EffectRegistry.create(_definitions[modifier_id], RunLoop.PLAYER)
	if effect is LossMeterEffect:
		var source: String = (effect as LossMeterEffect).source()
		values["amount"] = RunLoop.DEFAULT_METERS.source(source).amount
	return values


func _type_plural(type: int) -> String:
	return tr("pattern.plural." + String(Pattern.Type.keys()[type]).to_lower())


func target() -> float:
	return _loop.target()


## A copy of the roster entry in a villager's seat, or null when the run seats no roster.
func seated(seat: int) -> RosterEntry:
	var state: RunState = _loop.state
	if state.roster.is_empty() or seat <= 0 or seat >= state.table.size():
		return null
	var entry: RosterEntry = Roster.entry(state, state.table[seat])
	return null if entry == null else RosterEntry.from_dict(entry.to_dict())


## The family in a villager's seat, or null when the run seats no roster.
func seated_family(seat: int) -> FamilyDef:
	var entry: RosterEntry = seated(seat)
	return null if entry == null else Roster.definition(RunLoop.DEFAULT_VILLAGE, entry)


## The surname key shown for a villager's seat, or "" when the run seats no roster.
func seated_name_key(seat: int) -> String:
	var entry: RosterEntry = seated(seat)
	return "" if entry == null else Roster.name_key(RunLoop.DEFAULT_VILLAGE, entry)


## The full name of the family in a villager's seat, "Jianguo Wang", or its surname
## alone in a run that names nobody, as the demo's villagers are (ADR 0028).
func seated_full_name(seat: int) -> String:
	return RunPeople.seat_full_name(_loop.state, seat)


## The seated family's voice as this generation has it, or null with no roster.
func seated_voice(seat: int) -> VoiceProfile:
	return RunPeople.seat_voice(_loop.state, seat)


## The player's full name in this run, or their surname alone in one that names nobody.
func player_name() -> String:
	return RunPeople.player_full_name(_loop.state)


## How the run ended, for the ending screen (ADR 0024), worked out from its state alone.
func ending() -> EndingView:
	return EndingView.of(_loop.state, RunPeople.player_surname(_loop.state))


## The surname key of a family in the run's roster, or "" for one it does not hold.
func family_name_key(family_id: String) -> String:
	var entry: RosterEntry = Roster.entry(_loop.state, family_id)
	return "" if entry == null else Roster.name_key(RunLoop.DEFAULT_VILLAGE, entry)


## True when the family in a villager's seat is gone from the village: dead, or deposed
## until the next Year. Its panel is not shown again (ADR 0025).
func seat_gone(seat: int) -> bool:
	var state: RunState = _loop.state
	if seat <= 0 or seat >= state.table.size():
		return false
	return VillageFates.is_gone(state, state.table[seat])


## The most rounds a Set of this run plays.
func max_rounds() -> int:
	return _loop.sets().max_rounds()


## True when the run seats the village's roster, as a full run does. The demo seats its
## two fixed villagers and ends on its own closing screen instead of an ending.
func has_village() -> bool:
	return not _loop.state.roster.is_empty()


## True for a full run: the one-time tooltips show only there (ADR 0026).
func is_full_run() -> bool:
	return _loop.state.identity.is_full()


## True for the arrival, which is never saved and never writes the profile.
func is_tutorial() -> bool:
	return _loop.state.identity.is_tutorial()


## True when a family in a villager's seat remembers anything of the player.
func remembers_seated() -> bool:
	var state: RunState = _loop.state
	for seat: int in range(1, state.table.size()):
		var family: String = state.table[seat]
		if not state.memory.counts.has(family):
			continue
		for count: float in state.memory.counts[family]:
			if count != 0.0:
				return true
	return false


## Lets the run go, as when the arrival ends: no save or profile is touched.
func drop() -> void:
	_searches.let_go()
	_loop = null
	file_watch.dropped()


## Takes figures reported from outside the game as official (ADR 0022), by
## RunCorrections' names. The file's detectors send it; it is a command like any other.
func books(figures: Dictionary) -> int:
	return _act("books", _loop.player_books.bind(figures.duplicate()))


## For development tools and tests only: after changing the run's figures directly, tells
## the second book the change was meant, so the next command compares against it.
func reseal_book() -> void:
	if _loop != null:
		file_watch.sealed(_loop)


## A copy of the run state, for display.
func state_copy() -> RunState:
	return RunState.from_dict(_loop.state.to_dict())


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
	var known: Array[ModifierDef] = (
		RunLoop.DEFAULT_POOL.debuffs + RunLoop.DEFAULT_CADRES.cadres + RunLoop.DEFAULT_MARKET.cadres
	)
	for definition: ModifierDef in known + RunLoop.DEFAULT_BOSSES.all():
		_definitions[definition.id] = definition
	for directive_def: DirectiveDef in RunLoop.DEFAULT_DIRECTIVES.directives:
		_directives[directive_def.id] = directive_def
	_saves = saves
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


func _campaign(campaign_id: String) -> CampaignDef:
	return _loop.campaigns.definition(campaign_id)


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
## starts the search for a villager the loop stands still for if none runs (P5.0).
func _process(_delta: float) -> void:
	var play: BotPlay = _searches.poll(_loop)
	if play != null:
		_hand_in(play)
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
	var play: BotPlay = _searches.wait(_loop)
	if play == null:
		play = _search_now()
	_hand_in(play)


## Searches still running on the pool, for tests: one for the villager awaited now, and
## any let go of that have yet to finish.
func searches_running() -> int:
	return _searches.running()


func _awaits_villager() -> bool:
	return _loop != null and _loop.awaiting() == RunLoop.Awaiting.VILLAGER_SEARCH


## Answers a villager the loop stands still for (P5.0). In the tree its search starts on
## the pool and _process hands the play in. Outside it, as for a caller that never runs
## frames, each such villager is searched at once on this thread, as before P5.0. True
## when plays went in here.
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
## end a round and bank Grain (P4.19), before anyone is told what the run waits on now.
func _hand_in(play: BotPlay) -> void:
	var reason: RunLoop.Reason = _loop.villager_play(play)
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
## ProfileCommits takes each only once.
func _remember(at: RunFlow.State) -> void:
	if _profile == null:
		return
	if at == RunFlow.State.SET_END or at == RunFlow.State.RUN_END:
		ProfileCommits.commit(_profile, _loop.state, at == RunFlow.State.RUN_END)
