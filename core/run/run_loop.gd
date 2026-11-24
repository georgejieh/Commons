# gdlint: disable=max-file-lines,max-public-methods
# Over 400 lines and 20 public methods: the loop is the one command surface RunRecord
# replays and the controller reads, kept in one file.
class_name RunLoop
extends RefCounted
## Plays a run's Sets round by round: deal, bidding, plot swaps, play, scoring, banking,
## seat persistence, debuffs, meters and Set completion. The player sits in seat 0 and
## acts through commands; bots act in advance(). A Set is rebuilt from the RunState at
## its start plus the player's commands, which is how saves inside a Set resume.

enum Awaiting {
	NOTHING,
	PLAYER_BID,
	PLAYER_SWAP,
	PLAYER_PLAY,
	PLAYER_NEED,
	SET_OVER,
	SHOP,
	RUN_OVER,
	REEDUCATION,
	## Before the first play, a peasant player holding a Campaign for that moment may use
	## it, then plays on with player_begin() (ADR 0021).
	PLAYER_OPENING,
	## A searching villager's play is being decided outside the loop (P5.0): read what the
	## search needs from search_request() and hand the play in with villager_play().
	VILLAGER_SEARCH,
}
enum Reason { OK, NOT_AWAITED, ILLEGAL }

const PLAYER: int = 0
const DEFAULT_PARAMS: RunParams = preload("res://data/run/default_run.tres")
const DEFAULT_POOL: DebuffPool = preload("res://data/run/debuff_pool.tres")
const DEFAULT_CADRES: CadrePool = preload("res://data/run/cadre_pool.tres")
## Private items the black market sells (P4.9 effects, P4.10 stock).
const DEFAULT_MARKET: CadrePool = preload("res://data/run/market_pool.tres")
const DEFAULT_SHOP: ShopParams = preload("res://data/run/default_shop.tres")
const DEFAULT_BLACK_MARKET: ShopParams = preload("res://data/run/black_market.tres")
## The Directives the state store sells (ADR 0021).
const DEFAULT_DIRECTIVES: DirectivePool = preload("res://data/run/directive_pool.tres")
const DEFAULT_PLOT_UPGRADES: PlotUpgradeParams = preload("res://data/run/plot_upgrades.tres")
const DEFAULT_METERS: MeterTable = preload("res://data/run/meters.tres")
const DEFAULT_RESENTMENT: ResentmentParams = preload("res://data/run/resentment.tres")
const DEFAULT_AUDIT: AuditParams = preload("res://data/run/audit.tres")
const DEFAULT_FREE_RIDE: FreeRideParams = preload("res://data/run/free_ride.tres")
const DEFAULT_VILLAGE: VillageBook = preload("res://data/villagers/village.tres")
const DEFAULT_MEMORY: MemoryParams = preload("res://data/villagers/memory.tres")
const DEFAULT_BOSSES: BossPool = preload("res://data/run/boss_pool.tres")
## What the loop waits on when a books command may come: the player is to act.
const BOOKS_AWAITING: Array[Awaiting] = [
	Awaiting.PLAYER_BID,
	Awaiting.PLAYER_SWAP,
	Awaiting.PLAYER_PLAY,
	Awaiting.PLAYER_NEED,
	Awaiting.SET_OVER,
	Awaiting.SHOP,
	Awaiting.REEDUCATION,
	Awaiting.PLAYER_OPENING,
]

var state: RunState
var flow: RunFlow
var record: RunRecord = RunRecord.new()
## How searching villagers decide, and their plays written to the record (ADR 0030).
var decisions: SearchedDecisions = SearchedDecisions.new(record)
## Called with the loop after every state move, for autosaves.
var on_boundary: Callable = Callable()
var set_log: SetLog = SetLog.new()
## The state store between Sets. Read it freely; buy and reroll through the commands.
var shop: RunShop
## The black market's counter, open for the same visit as the state store.
var market: RunShop
## The black market's cards for the private plot.
var stall: PlotStall
## The player's Campaigns and what they hold in force this round. Use them through the
## commands.
var campaigns: RunCampaigns
## What the round's debuffs hold outside their hooks (ADR 0023).
var debuffs: RunDebuffs
## Bot actions the round refused, which a bot must never choose. Tests read it.
var refused_bot_actions: int = 0
## What this run may be offered, and its stake's numbers (ADR 0025).
var pools: RunPools
## The arrival's script, for a tutorial run only (ADR 0026); null for every other run.
var tutorial: RunTutorial = null

var _configs: Array[BotConfig]
var _sets: SetConfig
var _params: RunParams
var _meters: MeterTable
var _pool: Array[ModifierDef]
var _pool_by_id: Dictionary[String, ModifierDef] = {}
var _stack: ModifierStack = ModifierStack.new()
var _table: SeatRules
var _seat: LandlordSeat = LandlordSeat.new()
var _scoring: RoundScoring
var _awaiting: Awaiting = Awaiting.NOTHING
var _deal: DealResult
var _bidding: Bidding
var _round: RoundState
var _round_seen: int = 0
## While the loop stands still for a villager's search: what the search reads, and the
## loop's own copy of the moves the answer must be among.
var _request: SearchRequest = null
var _request_legal: Array[Pattern] = []


## configs has one entry per seat; the player's entry is unused.
func _init(
	run_state: RunState,
	configs: Array[BotConfig],
	sets: SetConfig = SetConfig.new(),
	params: RunParams = DEFAULT_PARAMS,
	pool: Array[ModifierDef] = DEFAULT_POOL.debuffs,
	meters: MeterTable = DEFAULT_METERS
) -> void:
	state = run_state
	flow = RunFlow.new(run_state.phase)
	_configs = configs
	pools = RunPools.new(run_state.identity)
	_sets = sets.under_stake(pools.stake)
	_params = params
	_meters = meters
	_pool = pool
	var known: Array[ModifierDef] = pool + all_cadres()
	for definition: ModifierDef in known + DEFAULT_BOSSES.all():
		_pool_by_id[definition.id] = definition
	shop = RunShop.new(
		state,
		pools.store,
		pools.store_cadres,
		meters.rationing_shop_cut,
		pools.directives,
		pools.store_campaigns,
		pools.reforms,
		params
	)
	var no_directives: Array[DirectiveDef] = []
	var no_reforms: Array[ReformDef] = []
	market = RunShop.new(
		state,
		pools.market,
		pools.market_cadres,
		0,
		no_directives,
		pools.market_campaigns,
		no_reforms,
		params
	)
	stall = PlotStall.new(state, pools.plot_cards, params)
	if run_state.identity.is_tutorial():
		tutorial = RunTutorial.new(RunTutorial.SCRIPT, configs)
		tutorial.on_fault = func() -> void: refused_bot_actions += 1
	_table = SeatRules.new(_stack)
	campaigns = RunCampaigns.new(state, _stack, _table, meters, params, set_log, PLAYER)
	campaigns.quota_target = target
	debuffs = RunDebuffs.new(state, _stack, set_log, PLAYER)
	_scoring = RoundScoring.new(state.hand_levels, _stack)


## Every Cadre either shop sells: the collective ones and the private ones.
static func all_cadres() -> Array[ModifierDef]:
	return DEFAULT_CADRES.cadres + DEFAULT_MARKET.cadres


func awaiting() -> Awaiting:
	return _awaiting


func events() -> Array[RunEvent]:
	return set_log.events()


## The current round, for views. Null between rounds.
func round_state() -> RoundState:
	return _round


## The player's cards: the dealt hand before play, the round's hand during it, and none
## between deals.
func player_cards() -> Array[CardInstance]:
	if _round != null:
		return _round.view_for(PLAYER).own_cards
	var cards: Array[CardInstance] = []
	if _deal == null:
		return cards
	for card: CardInstance in _deal.hands[PLAYER].cards():
		cards.append(card.snapshot())
	return cards


## The player's view of the round: the public view and their own cards, plus whatever
## their information upgrades reveal (P4.9). Null between rounds.
func player_view() -> SeatView:
	if _round == null:
		return null
	var view: SeatView = _round.view_for(PLAYER)
	var held: Array[ModifierDef] = []
	for cadre_id: String in state.inventory.cadres:
		held.append(_pool_by_id[cadre_id])
	var info_flags: int = InfoReveal.flags(held)
	if info_flags != 0:
		view.info = InfoReveal.build(_round, PLAYER, info_flags, seat_table(PLAYER))
	return view


## What the player's cards would score if played now, through the real scoring path, as
## reading when one is named (ADR 0029), else as their strongest reading.
func preview_play(card_ids: Array[int], reading: Pattern = null) -> PlayPreview:
	return _scoring.preview(_round, PLAYER, card_ids, reading)


## What the seat's rules and rank order are, for bots and hints.
func seat_table(seat: int) -> BotTable:
	_table.refresh()
	return BotTable.new(_table.rules_for(seat), _table.map_for(seat))


## The current Set's target: the curve's, any boss's change, then the norm in force for
## this Set, which leaves out what the Set itself earned once it is over and what a False
## Report raised it by in the Set (ADR 0032), then the
## family's file and the corrections in force (ADR 0022).
func target() -> float:
	var base: float = _sets.target(state.year, state.set_type)
	if state.boss_id != RunState.NO_BOSS:
		var boss: ModifierDef = _pool_by_id[state.boss_id]
		var percent: int = boss.parameters.get(GreatLeapEffect.QUOTA_PERCENT, 100)
		base = base * percent / 100.0
	var steps: int = state.norm_steps - state.over_steps - state.reported_steps
	return RunBooks.raised_target(_sets.normed(base, steps), state)


## Starts the Set the state names. The Set's start is the save checkpoint.
func start_set() -> Reason:
	if not RunFlow.allows(flow.state(), RunFlow.State.SET_INTRO):
		return Reason.NOT_AWAITED
	# A Quota's first round is always shuffled, Unplanned Economy or not.
	state.deck_order.clear()
	state.quota_corruption.clear()
	RunBooks.start_quota(state)
	record.mark(state)
	_seat_roster()
	set_log.start_set(state, set_number())
	_move(RunFlow.State.SET_INTRO)
	state.round_index = 0
	state.set_progress = 0.0
	state.over_steps = 0
	state.reported_steps = 0
	state.landlord_seat = Seats.NONE
	_choose_boss()
	var ladder_stream: RandomStream = state.streams.stream(RandomStreams.DEBUFF)
	state.debuff_ladder = DebuffLadder.draw(
		_pool, state.set_type, _sets.max_rounds(), ladder_stream, pools.ladder
	)
	state.slogan_type = RunDebuffs.draw_slogan(state.debuff_ladder, ladder_stream)
	var ladder_text: String = ",".join(state.debuff_ladder.slice(1))
	set_log.add(
		RunEvent.new(RunEvent.Type.SET_STARTED, Seats.NONE, set_number(), target(), ladder_text)
	)
	_start_round()
	return Reason.OK


## Picks up at a checkpoint: past a Set or the run, or at a Set's start.
func resume_at_checkpoint() -> void:
	match state.phase:
		RunFlow.State.SET_END:
			_awaiting = Awaiting.SET_OVER
		RunFlow.State.RUN_END:
			_awaiting = Awaiting.RUN_OVER
		_:
			start_set()


## Starts the round state.round_index names.
func _start_round() -> void:
	set_log.start_round()
	campaigns.start_round()
	_rebuild_modifiers()
	_seat = LandlordSeat.new()
	_seat.assign(state.landlord_seat)
	_deal_cards()
	if _seat.needs_bidding():
		_move(RunFlow.State.BIDDING)
		_bidding = Bidding.new(_first_bidder())
	else:
		_begin_play()
	advance()


## Runs bots until the player must act or the Set is over, or a replayed decision fails.
func advance() -> void:
	while _awaiting == Awaiting.NOTHING and not decisions.failed():
		if _bidding != null:
			_bot_bid()
		elif _round != null:
			_bot_play()
		else:
			return


## Who holds the seat in the bidding under way: Seats.NONE until someone calls.
func bid_holder() -> int:
	return Seats.NONE if _bidding == null else _bidding.landlord()


func player_bid(claim: bool) -> Reason:
	if _awaiting != Awaiting.PLAYER_BID:
		return Reason.NOT_AWAITED
	_awaiting = Awaiting.NOTHING
	record.add({"type": "bid", "claim": claim})
	# Calling an open seat is free. Taking it from a neighbour who holds it is resented.
	# It is charged before the bid is recorded: a grab can end the bidding and start the
	# round, and the villagers' grudge for that round must already count it.
	if claim and bid_holder() != Seats.NONE:
		_resent(DEFAULT_RESENTMENT.grab, Resentment.GRAB)
	_record_bid(PLAYER, claim)
	advance()
	return Reason.OK


## Brings plot cards into the hand for this round, one for one for hand cards, up to the
## round's swaps; the plot itself is unchanged (ADR 0038). No cards is a decline.
func player_swap(hand_ids: Array[int], plot_ids: Array[int]) -> Reason:
	if _awaiting != Awaiting.PLAYER_SWAP:
		return Reason.NOT_AWAITED
	var hand: Array[CardInstance] = _round.view_for(PLAYER).own_cards
	var limit: int = swap_limit()
	if not PlotSwap.is_valid(hand, state.inventory, hand_ids, plot_ids, limit):
		return Reason.ILLEGAL
	record.add({"type": "swap", "hand": hand_ids.duplicate(), "plot": plot_ids.duplicate()})
	PlotSwap.apply(_round, PLAYER, state, hand_ids, plot_ids)
	set_log.add(RunEvent.new(RunEvent.Type.SWAPPED, PLAYER, hand_ids.size()))
	_awaiting = _opening()
	advance()
	return Reason.OK


## No cards is a pass. reading names how the cards are read when they can be read more
## than one way (ADR 0029); with none, the strongest reading that may be played stands.
## The record keeps the reading only when the cards alone would not settle it.
func player_play(card_ids: Array[int], reading: Pattern = null) -> Reason:
	if _awaiting != Awaiting.PLAYER_PLAY:
		return Reason.NOT_AWAITED
	var action: RoundAction = RoundAction.new(PLAYER, card_ids)
	action.reading = reading
	var saved: Pattern = _reading_to_save(action)
	if _round.apply(action) != RoundState.Reason.OK:
		return Reason.ILLEGAL
	var command: Dictionary = {"type": "play", "cards": card_ids.duplicate()}
	if saved != null:
		command[ReadingCodec.KEY] = ReadingCodec.encode(saved)
	record.add(command)
	_awaiting = Awaiting.NOTHING
	_collect_round_events()
	# An Anonymous Letter in force acts on this play before the round can end.
	campaigns.after_player_play(card_ids.is_empty(), _round)
	if _round.is_over():
		_finish_round()
	advance()
	return Reason.OK


## Uses the held Campaign in slot, on the chosen hand cards when it asks for any. A
## refused use changes nothing; campaign_reason() says why.
func player_campaign(slot: int, card_ids: Array[int]) -> Reason:
	var moment: CampaignContext.Moment = _campaign_moment()
	if moment == CampaignContext.Moment.ELSEWHERE:
		return Reason.NOT_AWAITED
	if campaigns.check(slot, card_ids, moment, _round) != CampaignEffect.Reason.OK:
		return Reason.ILLEGAL
	record.add({"type": "campaign", "slot": slot, "cards": card_ids.duplicate()})
	campaigns.use(slot, card_ids, moment, _round)
	debuffs.after_campaign(campaigns.flags.round_debuff, _deal)
	if moment == CampaignContext.Moment.SHOP:
		_end_if_dead()
	elif moment == CampaignContext.Moment.OPENING and not campaigns.wants_opening(_round):
		_awaiting = Awaiting.NOTHING
		advance()
	return Reason.OK


## Why the held Campaign in slot cannot be used now on these cards, or OK. With
## check_cards false the cards are left aside, for a tray that has not chosen yet.
func campaign_reason(
	slot: int, card_ids: Array[int] = [], check_cards: bool = true
) -> CampaignEffect.Reason:
	var moment: CampaignContext.Moment = _campaign_moment()
	if not check_cards:
		return campaigns.availability(slot, moment, _round)
	return campaigns.check(slot, card_ids, moment, _round)


## Leaves the opening for the round's first play.
func player_begin() -> Reason:
	if _awaiting != Awaiting.PLAYER_OPENING:
		return Reason.NOT_AWAITED
	record.add({"type": "begin"})
	_awaiting = Awaiting.NOTHING
	advance()
	return Reason.OK


## Buys the state store's Campaign, or the black market's, which adds Resentment as any
## purchase there does.
func player_campaign_buy(slot: int) -> Reason:
	var act: Callable = shop.campaigns.buy.bind(slot)
	return _shop_command({"type": "campaign_buy", "slot": slot}, act)


func player_market_campaign(slot: int) -> Reason:
	var act: Callable = market.campaigns.buy.bind(slot)
	var reason: Reason = _shop_command({"type": "market_campaign", "slot": slot}, act)
	if reason == Reason.OK:
		_market_bought()
	return reason


## Enacts the state store's Reform: it lasts the rest of the run (ADR 0021).
func player_reform(slot: int) -> Reason:
	return _shop_command({"type": "reform", "slot": slot}, shop.reforms.buy.bind(slot))


## Buys the state store's envelope, which opens it at once (ADR 0021). Until the player
## keeps one of its items or nothing, every other shop command is refused.
func player_envelope_buy(slot: int) -> Reason:
	var act: Callable = shop.envelopes.buy.bind(slot)
	return _shop_command({"type": "envelope_buy", "slot": slot}, act)


## Buys the black market's Parcel: a private purchase, resented when it is bought.
func player_market_envelope(slot: int) -> Reason:
	var act: Callable = market.envelopes.buy.bind(slot)
	var reason: Reason = _shop_command({"type": "market_envelope", "slot": slot}, act)
	if reason == Reason.OK:
		_market_bought()
	return reason


## Keeps the open envelope's item at index, or nothing with EnvelopeCounter.NOTHING, and
## closes it. A refused pick changes nothing and leaves it open.
func player_envelope_pick(index: int) -> Reason:
	var opened: EnvelopeCounter = open_envelope()
	if _awaiting != Awaiting.SHOP or opened == null:
		return Reason.NOT_AWAITED
	if opened.pick(index, PLAYER) != RunShop.Reason.OK:
		return Reason.ILLEGAL
	record.add({"type": "envelope_pick", "index": index})
	return Reason.OK


## Takes figures reported from outside the game as official (ADR 0022): coupons, progress,
## the three meters and the norm, by RunCorrections' names, each clamped to its field.
## Never refused for being untrue; refused only when malformed, or while the loop is not
## waiting on the player. A meter raised to its death ends the run at once away from the
## table, and at the round's end at it, as every meter change does.
func player_books(figures: Dictionary) -> Reason:
	if not BOOKS_AWAITING.has(_awaiting):
		return Reason.NOT_AWAITED
	if not RunCorrections.is_valid(figures):
		return Reason.ILLEGAL
	var books: BooksParams = RunBooks.DEFAULT_PARAMS
	var kept: Dictionary = RunCorrections.clamped(figures, _params, DEFAULT_RESENTMENT, books)
	record.add({"type": "books", "figures": kept})
	var correction: BooksCorrection = RunCorrections.apply(
		state, kept, target(), _meters, _params, DEFAULT_RESENTMENT, books, set_log.events(), PLAYER
	)
	var corrected: RunEvent = RunEvent.new(
		RunEvent.Type.BOOKS_CORRECTED,
		PLAYER,
		state.books.corrections,
		0.0,
		",".join(correction.figures)
	)
	corrected.correction = correction
	set_log.add(corrected)
	if [Awaiting.SET_OVER, Awaiting.SHOP, Awaiting.REEDUCATION].has(_awaiting):
		_end_if_dead()
	return Reason.OK


## The counter whose envelope is open now, or null.
func open_envelope() -> EnvelopeCounter:
	for counter: RunShop in [shop, market]:
		if counter.envelopes.is_open():
			return counter.envelopes
	return null


func player_need(need: int) -> Reason:
	if _awaiting != Awaiting.PLAYER_NEED:
		return Reason.NOT_AWAITED
	record.add({"type": "need", "need": need})
	_awaiting = Awaiting.NOTHING
	_split_commons(need)
	advance()
	return Reason.OK


## Leaves a finished Set for the state store, or for reeducation when it is owed.
func open_shop() -> Reason:
	if _awaiting != Awaiting.SET_OVER:
		return Reason.NOT_AWAITED
	record.add({"type": "shop"})
	if state.reeducation_due:
		_reeducate()
		return Reason.OK
	_move(RunFlow.State.SHOP)
	shop.short_cut = RunDebuffs.store_cut(state, _pool_by_id, PLAYER)
	shop.open()
	market.open()
	_read_shop_rules()
	stall.open()
	# Last on the shop stream, so Directives, Campaigns and Reforms change none of the
	# stock drawn before them.
	shop.stock_directives()
	shop.campaigns.draw()
	market.campaigns.draw()
	shop.reforms.draw()
	# The envelopes last of all, so they leave every draw before them as it was.
	shop.envelopes.draw()
	market.envelopes.draw()
	_awaiting = Awaiting.SHOP
	return Reason.OK


func player_buy(slot: int) -> Reason:
	var bought: ModifierDef = _stocked(shop, slot)
	var reason: Reason = _shop_command({"type": "buy", "slot": slot}, shop.buy.bind(slot))
	if reason == Reason.OK:
		RunCadres.bought(state, bought, Ranks.INVALID)
		_read_shop_rules()
	return reason


func player_reroll() -> Reason:
	return _shop_command({"type": "reroll"}, shop.reroll)


## Issues a Directive from the state store: its hand types rise a level at once.
func player_directive(slot: int) -> Reason:
	return _shop_command({"type": "directive", "slot": slot}, shop.buy_directive.bind(slot))


## Buys from the black market. Every purchase there is a private one, and adds
## Resentment. A Cadre that needs a rank is refused without one from 3 to 2 (ADR 0021).
func player_market_buy(slot: int, rank: int = Ranks.INVALID) -> Reason:
	var bought: ModifierDef = _stocked(market, slot)
	if _awaiting == Awaiting.SHOP and not RunCadres.rank_fits(bought, rank):
		return Reason.ILLEGAL
	var command: Dictionary = {"type": "market_buy", "slot": slot}
	if rank != Ranks.INVALID:
		command["rank"] = rank
	var reason: Reason = _shop_command(command, market.buy.bind(slot))
	if reason == Reason.OK:
		RunCadres.bought(state, bought, rank)
		_read_shop_rules()
		_market_bought()
	return reason


## What the held Cadres change about this visit's counters, read as it opens and again
## after a Cadre is bought, so one bought now works at once (Back Door, ADR 0032).
func _read_shop_rules() -> void:
	var rules: ShopContext = RunCadres.shop_rules(state, _pool_by_id, PLAYER)
	market.free_rerolls = rules.free_market_rerolls


## The Cadre on a counter's slot, or null for an empty or sold one.
func _stocked(counter: RunShop, slot: int) -> ModifierDef:
	var stock: Array[String] = counter.stock()
	if slot < 0 or slot >= stock.size() or stock[slot] == RunShop.SOLD:
		return null
	return _pool_by_id[stock[slot]]


func player_market_reroll() -> Reason:
	return _shop_command({"type": "market_reroll"}, market.reroll)


## Buys a card for the private plot at the black market: a private purchase too.
func player_plot_card(slot: int) -> Reason:
	var act: Callable = func() -> RunShop.Reason:
		var bought: bool = stall.buy(slot) == PlotStall.Reason.OK
		return RunShop.Reason.OK if bought else RunShop.Reason.TOO_POOR
	var reason: Reason = _shop_command({"type": "plot_card", "slot": slot}, act)
	if reason == Reason.OK:
		_market_bought()
	return reason


## Buys a private-plot upgrade at the black market: a private purchase like any other.
func player_upgrade(kind: String) -> Reason:
	var act: Callable = func() -> RunShop.Reason:
		var bought: bool = PlotUpgrades.buy(state, kind, DEFAULT_PLOT_UPGRADES)
		return RunShop.Reason.OK if bought else RunShop.Reason.TOO_POOR
	var reason: Reason = _shop_command({"type": "upgrade", "kind": kind}, act)
	if reason == Reason.OK:
		_market_bought()
	return reason


## Moves past a finished Set or the shop: a Year's end after the boss, then the next Set.
## From a finished Set it passes through the shop without stopping.
func next_set() -> Reason:
	if not [Awaiting.SET_OVER, Awaiting.SHOP, Awaiting.REEDUCATION].has(_awaiting):
		return Reason.NOT_AWAITED
	# An open envelope is answered before the shops are left.
	if open_envelope() != null:
		return Reason.NOT_AWAITED
	if _awaiting == Awaiting.SET_OVER:
		_move(RunFlow.State.SHOP)
	_awaiting = Awaiting.NOTHING
	if state.set_type == RunState.SetType.BOSS:
		_move(RunFlow.State.YEAR_END)
		if state.year == _sets.years():
			_move(RunFlow.State.RUN_END, true)
			_awaiting = Awaiting.RUN_OVER
			return Reason.OK
		state.year += 1
		state.cadre_memos.new_year(state.inventory.cadres)
		YearClass.new_year(state)
		VillageFates.new_year(state, set_log)
	state.set_index = (state.set_index + 1) % SetConfig.SETS_PER_YEAR
	state.set_type = state.set_index as RunState.SetType
	return start_set()


func sets() -> SetConfig:
	return _sets


## Counts Sets across the run from 0.
func set_number() -> int:
	return (state.year - 1) * SetConfig.SETS_PER_YEAR + state.set_index


## Cadres in slot order, then the ladder's debuffs so far, as the hook order says.
func _rebuild_modifiers() -> void:
	_stack.clear()
	for cadre_id: String in state.inventory.cadres:
		_stack.add(_pool_by_id[cadre_id], PLAYER, state.cadre_memos.entry(cadre_id))
	# A Reform's rule for every seat, such as Industrialization's bigger bombs (ADR 0029).
	for rule: ActiveModifier in RunReforms.table_rules(state):
		_stack.add_entry(rule)
	for round_index: int in range(1, state.round_index + 1):
		var id: String = state.debuff_ladder[round_index]
		if id == RunState.NO_DEBUFF:
			continue
		var entry: ActiveModifier = _stack.add(_pool_by_id[id], PLAYER)
		if round_index == state.round_index:
			campaigns.flags.round_debuff = entry
			set_log.add(RunEvent.new(RunEvent.Type.DEBUFF_ADDED, PLAYER, round_index, 0.0, id))
	if state.boss_id != RunState.NO_BOSS:
		_stack.add(_pool_by_id[state.boss_id], PLAYER)
	debuffs.rebuilt()


## Shuffles a fresh deck, or under Unplanned Economy cuts the one the last round left
## (DeckOrder). Either way the marks saved on deck cards go back on (ADR 0021). The
## arrival deals its authored decks (ADR 0026).
func _deal_cards() -> void:
	var stream: RandomStream = state.streams.stream(RandomStreams.DEAL)
	if tutorial != null:
		_deal = tutorial.deal(state.round_index, pools.audit)
	elif RunReforms.gathers_deck(state) and not state.deck_order.is_empty():
		_deal = DeckOrder.deal(state.deck_order, state.card_marks, stream)
	else:
		var cards: Array[CardInstance] = []
		for deck_id: int in Deck.generate():
			cards.append(CardInstance.from_deck_id(deck_id))
		state.card_marks.apply(cards)
		_deal = Dealer.deal(cards, stream)
	_stack.run_on_deal(DealContext.new(state.landlord_seat, _deal, stream))
	set_log.add(RunEvent.new(RunEvent.Type.DEALT, Seats.NONE, state.round_index))
	# Mass Line's rank is drawn after the deal on its stream, so the deal is unchanged and
	# every seat knows it before the bid (ADR 0029).
	for _rank: int in RunReforms.wild_ranks_per_round(state):
		if RunWild.has_room(state):
			var rank: int = RunWild.add(state, stream)
			set_log.add(RunWild.event(state, rank))
			_table.set_wild_ranks(state.wild_ranks)


## Who bids first moves round the table with the year, Set and round, so no seat always
## opens a Set's bidding.
func _first_bidder() -> int:
	return (state.year + state.set_index + state.round_index) % Seats.COUNT


func _bot_bid() -> void:
	var seat: int = _bidding.seat_to_act()
	if seat == PLAYER:
		_awaiting = Awaiting.PLAYER_BID
		return
	var claim: bool = Bot.decide_bid(
		_deal.hands[seat].counts(),
		_bidding.phase() == Bidding.Phase.GRABBING,
		_bidding.is_last_to_act(),
		seat_table(seat),
		_configs[seat],
		BotBudget.unlimited()
	)
	_record_bid(seat, claim)


func _record_bid(seat: int, claim: bool) -> void:
	_bidding.act(seat, claim)
	set_log.add(RunEvent.new(RunEvent.Type.BID, seat, 1 if claim else 0))
	if _bidding.phase() != Bidding.Phase.DONE:
		return
	if _bidding.needs_redeal():
		set_log.add(RunEvent.new(RunEvent.Type.REDEALT))
		_move(RunFlow.State.BIDDING)
		# A deal nobody bid on was never played, so a redeal is shuffled, and Mass Line
		# draws its rank again with the new deal.
		state.deck_order.clear()
		if RunReforms.wild_ranks_per_round(state) > 0:
			state.wild_ranks.clear()
		_deal_cards()
		_bidding = Bidding.new(_first_bidder())
		return
	_seat.assign(_bidding.landlord())
	state.landlord_seat = _bidding.landlord()
	set_log.add(RunEvent.new(RunEvent.Type.LANDLORD_CHOSEN, _bidding.landlord(), _bidding.stake()))
	_bidding = null
	_begin_play()


func _begin_play() -> void:
	_move(RunFlow.State.ROUND_PLAY)
	# The round starts first, so the landlord holds the kitty before the swap (ADR 0038).
	# While the swap waits, advance() stands still: no seat plays before it is answered.
	_create_round()
	if not state.inventory.plot.is_empty() and swap_limit() > 0:
		_awaiting = Awaiting.PLAYER_SWAP
	else:
		_awaiting = _opening()


## The most plot swaps the player may make this round: the run's own, under any debuff's
## cap (ADR 0023).
func swap_limit() -> int:
	return debuffs.swaps(PlotSwap.swaps(state, _params))


## A peasant player holding a Campaign for the opening is asked before the first play.
func _opening() -> Awaiting:
	return Awaiting.PLAYER_OPENING if campaigns.wants_opening(_round) else Awaiting.NOTHING


## Where the run stands for a Campaign: the opening, the player's turn, a shop or
## elsewhere.
func _campaign_moment() -> CampaignContext.Moment:
	match _awaiting:
		Awaiting.PLAYER_OPENING:
			return CampaignContext.Moment.OPENING
		Awaiting.PLAYER_PLAY:
			return CampaignContext.Moment.TURN
		Awaiting.SHOP:
			if open_envelope() == null:
				return CampaignContext.Moment.SHOP
	return CampaignContext.Moment.ELSEWHERE


func _create_round() -> void:
	_aim_grudges()
	# The round's wild ranks (ADR 0029), none unless an item drew them.
	_table.set_wild_ranks(state.wild_ranks)
	_round = RoundState.new(_deal, state.landlord_seat, _table)
	_round_seen = 0
	_scoring.start(state.landlord_seat, state.year)
	# Debuffs move cards here, after the kitty and before the plot swap (ADR 0023).
	var opening: RoundContext = debuffs.round_context(_round, _table, campaigns.flags.round_debuff)
	_stack.run_round_start(opening)
	debuffs.started(opening)
	_collect_round_events()


func _bot_play() -> void:
	var seat: int = _round.seat_to_act()
	if seat == PLAYER:
		_awaiting = Awaiting.PLAYER_PLAY
		return
	if campaigns.forces_pass(seat, _round):
		_round.apply(RoundAction.new(seat))
		_after_action()
		return
	var config: BotConfig = _configs[seat]
	if decisions.replays(config):
		# A written play that no longer fits fails the resume, not the fallback below.
		if decisions.replay(_round, seat):
			_after_action()
		return
	var legal: Array[Pattern] = _round.legal_moves()
	if decisions.stands_for(config, legal):
		_request = decisions.request(seat, _round.view_for(seat), legal, seat_table(seat), config)
		_request_legal = legal
		_awaiting = Awaiting.VILLAGER_SEARCH
		return
	var play: BotPlay = decisions.decide(_round.view_for(seat), legal, seat_table(seat), config)
	_play_bot(seat, config, legal, play)


## What the search for the villager the loop stands still for reads (P5.0), or null
## while it waits on anything else. The search may read it on any thread.
func search_request() -> SearchRequest:
	return _request


## Takes the searched play of the villager the loop stands still for, and plays on (P5.0).
## A play that is not among its legal moves or a pass is refused as any bot's is: counted
## in refused_bot_actions, with the first legal move played instead. Not a player command:
## the record writes it with the villagers' decisions, never with the commands.
func villager_play(play: BotPlay) -> Reason:
	if _awaiting != Awaiting.VILLAGER_SEARCH:
		return Reason.NOT_AWAITED
	var seat: int = _request.seat
	var legal: Array[Pattern] = _request_legal
	_request = null
	_request_legal = []
	_awaiting = Awaiting.NOTHING
	_play_bot(seat, _configs[seat], legal, play)
	advance()
	return Reason.OK


## Plays a bot's chosen play, or the first legal move in place of one it may not make,
## and writes a searching seat's to the record.
func _play_bot(seat: int, config: BotConfig, legal: Array[Pattern], play: BotPlay) -> void:
	var action: RoundAction = RoundAction.new(seat)
	if not play.is_pass():
		action = _round.action_for(play.pattern)
	var offered: bool = (
		play.is_pass() or legal.any(func(move: Pattern) -> bool: return move.equals(play.pattern))
	)
	var saved: Pattern = _reading_to_save(action) if SearchedDecisions.searches(config) else null
	if not offered or _round.apply(action) != RoundState.Reason.OK:
		refused_bot_actions += 1
		assert(false, "A bot chose an illegal action")
		action = _round.action_for(legal[0])
		saved = _reading_to_save(action) if SearchedDecisions.searches(config) else null
		_round.apply(action)
	decisions.write(seat, config, action.card_ids, saved)
	_after_action()


## The reading a play's record must keep: the one it is played as, when the cards could be
## played more than one way. Null for a pass, a refused play or cards that read one way.
func _reading_to_save(action: RoundAction) -> Pattern:
	if action.card_ids.is_empty():
		return null
	var read: PlayReading = _round.read_play(action.seat, action.card_ids, action.reading)
	if read.reason != RoundState.Reason.OK or read.readings.size() < 2:
		return null
	return read.pattern


func _after_action() -> void:
	_collect_round_events()
	if _round.is_over():
		_finish_round()


func _collect_round_events() -> void:
	var round_events: Array[RoundEvent] = _round.events()
	for index: int in range(_round_seen, round_events.size()):
		var event: RoundEvent = round_events[index]
		set_log.add(RunEvent.wrap(event))
		if event.type == RoundEvent.Type.PLAYED:
			var total: float = _scoring.score(event, _round.remaining()[event.seat])
			# A hook may waive what the player's stamped cards add (Forged Seal, ADR 0032).
			if event.seat == PLAYER and _scoring.last_stamps_resented():
				_resent(
					(
						Resentment.stamped(event.cards, PLAYER, event.pattern)
						* DEFAULT_RESENTMENT.stamped_card
					),
					Resentment.STAMPED_CARD
				)
			var scored: RunEvent = RunEvent.new(RunEvent.Type.PLAY_SCORED, event.seat, 0, total)
			scored.grain = _scoring.last_grain()
			scored.rate = _scoring.last_rate()
			scored.zeal = _scoring.last_zeal()
			set_log.add(scored)
			_take_turn(event)
		elif event.type == RoundEvent.Type.PASSED:
			_take_turn(event)
	_round_seen = round_events.size()


## Hands a real play or pass to the Cadres that count them (ADR 0021).
func _take_turn(event: RoundEvent) -> void:
	var turn: TurnContext = RunCadres.take_turn(_stack, state, event, _round, PLAYER)
	_resent(turn.resentment, Resentment.CADRE)
	RunCadres.announce(state, set_log, PLAYER)


func _finish_round() -> void:
	_move(RunFlow.State.ROUND_END)
	var finish: RoundEvent.Finish = _round.events()[-1].value as RoundEvent.Finish
	var winner: int = _round.winner()
	var landlord: int = state.landlord_seat
	var ending: RoundContext = RoundContext.new(landlord, winner, finish)
	ending.landlord_cards = _round.remaining()[landlord]
	_stack.run_round_end(ending)
	debuffs.ended(ending)
	# Before the round is scored, so the Quota's summary reads it as the round's (ADR 0032).
	if ending.famine_fall > 0:
		var logged: Array[RunEvent] = set_log.events()
		var fall: int = ending.famine_fall
		RunMeters.lower(
			state, RunMeters.CADRE_FAMINE, fall, _meters, _stack, _params, PLAYER, logged
		)
	var totals: PackedFloat64Array = RoundTotals.totals(
		_scoring.scores(), landlord, winner, finish, _table.rules_for(landlord)
	)
	RunCadres.scale_commons(totals, landlord, ending.commons_scale)
	RunCadres.announce(state, set_log, PLAYER)
	campaigns.settle(totals, landlord, winner)
	debuffs.settle(totals, landlord)
	RoundBanking.bank(state, totals, PLAYER, set_log.events())
	for source: String in debuffs.meter_sources:
		_raise(source)
	if landlord != PLAYER:
		_awaiting = Awaiting.PLAYER_NEED
		return
	_split_commons(0)


## The chance that each declared need is audited at this round's split: the audit faces
## over the die's sides.
func audit_chance() -> float:
	return NeedAudit.chance(state, pools.audit, _stack)


func _split_commons(player_need: int) -> void:
	var faces: int = NeedAudit.faces(state, pools.audit, _stack)
	var caught: Array[int] = []
	var events: Array[RunEvent] = set_log.events()
	if RoundBanking.split(
		state,
		PLAYER,
		player_need,
		_configs,
		_params,
		events,
		faces,
		caught,
		pools.audit,
		debuffs.cut
	):
		_raise(RunMeters.COMMONS_SHORTFALL)
	for seat: int in caught:
		if seat == PLAYER:
			_raise(RunMeters.CAUGHT_LIE)
		else:
			_denounce_villager(seat)
	_settle_need(player_need, caught)
	if _end_if_dead():
		return
	_end_round()


## The Cadres that answer the split and its audit (ADR 0032): coupons for caught lies, and
## Resentment lowered for an honest claim, which only a peasant makes.
func _settle_need(player_need: int, caught: Array[int]) -> void:
	var declared: int = player_need
	if state.landlord_seat == PLAYER:
		declared = NeedContext.NOT_DECLARED
	var settled: NeedContext = RunCadres.settle_need(
		_stack, state, PLAYER, declared, _params.base_need, caught
	)
	if settled.resentment_fall > 0:
		Resentment.lower(
			state, settled.resentment_fall, Resentment.CADRE, DEFAULT_RESENTMENT, set_log.events()
		)
	RunCadres.announce(state, set_log, PLAYER)


## A caught villager's own Denunciation rises by the caught-lie row, as the player's does.
func _denounce_villager(seat: int) -> void:
	var family_id: String = state.table[seat]
	var before: int = state.villager_denunciation.get(family_id, 0)
	var amount: int = _meters.source(RunMeters.CAUGHT_LIE).amount
	var after: int = clampi(before + amount, 0, _params.meter_max)
	state.villager_denunciation[family_id] = after
	set_log.add(
		RunEvent.new(RunEvent.Type.VILLAGER_DENOUNCED, seat, after - before, 0.0, family_id)
	)


func _end_round() -> void:
	set_log.end_round(state, PLAYER)
	YearClass.count_round(state, _round.landlord(), PLAYER)
	var landlord_won: bool = _round.landlord_won()
	_seat.record_round(landlord_won)
	state.landlord_seat = _seat.holder()
	var kept: RunEvent.Type = RunEvent.Type.SEAT_KEPT if landlord_won else RunEvent.Type.SEAT_LOST
	set_log.add(RunEvent.new(kept, _round.landlord()))
	# What a Campaign held in force ends with its round, whatever comes next.
	campaigns.start_round()
	state.wild_ranks.clear()
	_table.set_wild_ranks(state.wild_ranks)
	state.deck_order.clear()
	if RunReforms.gathers_deck(state):
		state.deck_order = DeckOrder.gather(_round)
	_round = null
	_deal = null
	debuffs.round_over()
	state.round_index += 1
	if state.set_progress >= target() or state.round_index >= _sets.max_rounds():
		_end_set()
		return
	_start_round()


func _end_set() -> void:
	var met: bool = state.set_progress >= target()
	var steps: int = _sets.over_steps(state.set_progress, target()) if met else 0
	# Cadres that pay at a Quota's end are paid before the Quota is.
	var ending: SetContext = SetContext.new(state.set_index, met)
	ending.coupons = state.coupons
	ending.over_steps = steps
	_stack.run_set_end(ending)
	state.coupons += ending.add_coupons
	RunCadres.announce(state, set_log, PLAYER)
	if met:
		state.coupons += _sets.reward(state.set_type) + RunReforms.quota_coupons(state)
		_overfulfil(steps)
	else:
		var famine: int = _meters.source(RunMeters.MISSED_TARGET).amount
		RunMeters.apply_amount(
			state,
			RunMeters.MISSED_TARGET,
			RunReforms.missed_famine(state, famine),
			_meters,
			_stack,
			_params,
			PLAYER,
			set_log.events()
		)
	# A family that starves is dead before reeducation could take it (ADR 0025).
	VillageFates.starve(state, _meters.famine, DEFAULT_VILLAGE.starvations_per_year, set_log)
	if met:
		VillageFates.depose(state, DEFAULT_BOSSES.risen.id, set_log)
	_reeducate_villagers()
	state.memory.record(state.summaries[-1])
	_record_style_and_risen()
	_count_standing_by()
	CorruptionEvents.close_quota(state, set_log.events(), _params.base_need)
	var held: int = Resentment.private_cadres(state.inventory.cadres, all_cadres())
	_resent(held * DEFAULT_RESENTMENT.private_cadre, Resentment.PRIVATE_CADRE)
	_resent(steps * DEFAULT_RESENTMENT.overfulfilment, Resentment.OVERFULFILMENT)
	# What a Cadre adds for the steps on top of that (Grain Speculator, ADR 0032).
	_resent(ending.add_resentment, Resentment.CADRE)
	var owed: int = Resentment.denunciation(state.resentment, DEFAULT_RESENTMENT)
	if owed > 0:
		RunMeters.apply_amount(
			state, RunMeters.RESENTMENT, owed, _meters, _stack, _params, PLAYER, set_log.events()
		)
	_stack.clear()
	state.landlord_seat = Seats.NONE
	state.deck_order.clear()
	set_log.add(
		RunEvent.new(RunEvent.Type.SET_ENDED, Seats.NONE, 1 if met else 0, state.set_progress)
	)
	if steps > 0:
		set_log.add(RunEvent.new(RunEvent.Type.OVERFULFILLED, PLAYER, steps))
	_move(RunFlow.State.SET_END, true)
	_awaiting = Awaiting.SET_OVER
	_end_if_dead()


## A met Quota beaten by a step or more pays the bonus and raises the norm for every
## later Set. The steps are counted against the target in force for this Set, and stay
## in over_steps until the next Set starts, so target() still reads this Set's.
func _overfulfil(steps: int) -> void:
	state.coupons += _sets.over_bonus(steps)
	state.norm_steps += steps
	state.over_steps = steps


## Moves a meter by a source in the meter table. Callers check death at a boundary.
func _raise(source_id: String) -> void:
	RunMeters.apply(state, source_id, _meters, _stack, _params, PLAYER, set_log.events())


## A boss Set gets its boss: a Purge destroys Cadres now, a risen villager takes seat 1
## as landlord, and the New Landlord makes seat 1 play like the player.
func _choose_boss() -> void:
	state.boss_id = RunState.NO_BOSS
	state.boss_family = ""
	if state.set_type != RunState.SetType.BOSS:
		return
	var stream: RandomStream = state.streams.stream(RandomStreams.EVENTS)
	var boss: ModifierDef = Bosses.choose(state, DEFAULT_BOSSES, _sets.years(), stream)
	state.boss_id = boss.id
	set_log.add(RunEvent.new(RunEvent.Type.BOSS_CHOSEN, Seats.NONE, 0, 0.0, boss.id))
	var purge: int = boss.parameters.get("purge", 0)
	for cadre_id: String in Bosses.purge(state.inventory, purge, stream):
		set_log.add(RunEvent.new(RunEvent.Type.CADRE_PURGED, PLAYER, 0, 0.0, cadre_id))
	state.cadre_memos.keep_only(state.inventory.cadres)
	if boss == DEFAULT_BOSSES.risen:
		# The risen family takes seat 1; if the roster already sat it in seat 2, the two
		# seats trade so no family sits twice.
		if state.table[2] == state.boss_family:
			state.table[2] = state.table[1]
			var moved: BotConfig = _configs[1]
			_configs[1] = _configs[2]
			_configs[2] = moved
		state.table[1] = state.boss_family
		var entry: RosterEntry = Roster.entry(state, state.boss_family)
		if entry != null:
			_configs[1] = Roster.config_for(DEFAULT_VILLAGE, entry, _seat_seed(1), state.drift)
		state.landlord_seat = 1
	elif boss == DEFAULT_BOSSES.new_landlord:
		PlayerStyle.mirror(_configs[1], state.styles, DEFAULT_BOSSES)


## Keeps the player's last few Sets of play, and marks a villager who held the landlord
## seat all Set as risen.
func _record_style_and_risen() -> void:
	state.styles.append(PlayerStyle.from_events(set_log.events(), PLAYER))
	while state.styles.size() > DEFAULT_BOSSES.style_sets:
		state.styles.pop_front()
	var holder: String = Bosses.full_set_holder(set_log.events(), state.table, PLAYER)
	if holder != Bosses.NO_FAMILY and not state.risen.has(holder):
		state.risen.append(holder)


## A Set the player never held the landlord's seat in lengthens a run of them, and past
## the grace each one costs Famine, more for each Set until the most (ADR 0031). The last
## free Set and every one that costs are logged, so the summary can say which it was.
func _count_standing_by() -> void:
	if YearClass.held_seat(set_log.events(), PLAYER):
		state.seatless_sets = 0
		return
	state.seatless_sets += 1
	var steps: int = mini(state.seatless_sets - _params.seat_grace_sets, _params.seat_max_steps)
	# Before the last free Set, or past it with no steps to pay (a most of 0).
	if steps < 0 or (steps == 0 and state.seatless_sets > _params.seat_grace_sets):
		return
	var before: int = state.famine
	if steps > 0:
		var each: int = _meters.source(RunMeters.STOOD_BY).amount
		var logged: Array[RunEvent] = set_log.events()
		RunMeters.apply_amount(
			state, RunMeters.STOOD_BY, steps * each, _meters, _stack, _params, PLAYER, logged
		)
	set_log.add(RunEvent.new(RunEvent.Type.STOOD_BY, PLAYER, steps, float(state.famine - before)))


func _seat_seed(seat: int) -> int:
	return RandomStreams.derive_seed(state.run_seed, "seat:%d:%d" % [set_number(), seat])


## Seats two families from the roster and plays them by their personalities. A run
## with no roster keeps the seats and configs it was given.
func _seat_roster() -> void:
	if state.roster.is_empty():
		return
	Roster.prepare_set(state, DEFAULT_VILLAGE, state.streams.stream(RandomStreams.EVENTS))
	for seat: int in range(1, Seats.COUNT):
		var entry: RosterEntry = Roster.entry(state, state.table[seat])
		_configs[seat] = Roster.config_for(DEFAULT_VILLAGE, entry, _seat_seed(seat), state.drift)
		if Roster.definition(DEFAULT_VILLAGE, entry).mirrors_player:
			PlayerStyle.mirror(_configs[seat], state.styles, DEFAULT_BOSSES)


## A family whose own Denunciation reached mid is sent to reeducation, and its count
## starts again.
func _reeducate_villagers() -> void:
	# In name order: a save sorts its keys, so insertion order would not survive one.
	var families: Array = state.villager_denunciation.keys()
	families.sort()
	for family_id: String in families:
		if state.villager_denunciation[family_id] < _meters.denunciation.mid:
			continue
		var entry: RosterEntry = Roster.entry(state, family_id)
		if entry == null or entry.status != RosterEntry.Status.ACTIVE:
			continue
		Roster.reeducate(state, family_id, DEFAULT_VILLAGE)
		state.villager_denunciation[family_id] = 0
		set_log.add(
			RunEvent.new(RunEvent.Type.ROSTER_CHANGED, Seats.NONE, entry.status, 0.0, family_id)
		)


## Every black-market purchase is resented, and counted when it comes in a famine.
## In the arrival someone sees it, too, and Denunciation rises by its own row (ADR 0026).
func _market_bought() -> void:
	_resent(DEFAULT_RESENTMENT.private_purchase, Resentment.PRIVATE_PURCHASE)
	CorruptionEvents.note_purchase(state, _meters.famine)
	if tutorial != null:
		RunMeters.apply_amount(
			state,
			RunTutorial.DENUNCIATION_ROW,
			tutorial.denunciation(),
			_meters,
			_stack,
			_params,
			PLAYER,
			set_log.events()
		)


func _resent(amount: int, cause: String) -> void:
	if amount != 0:
		Resentment.add(state, amount, cause, DEFAULT_RESENTMENT, set_log.events())


## Every bot holds the player's Resentment against them, plus its family's memory.
## The player's teammate, when they have one, slacks as the player's Commons share grows,
## and covers for the player more as its family's warmth grows.
func _aim_grudges() -> void:
	var held: float = Resentment.grudge(state.resentment, DEFAULT_RESENTMENT)
	var share: float = FreeRiding.share(state)
	for seat: int in Seats.COUNT:
		if seat == PLAYER:
			continue
		var memory: PackedFloat32Array = _configs[seat].memory
		memory[PLAYER] = held + state.memory.pull(state.table[seat], DEFAULT_MEMORY)
		_configs[seat].memory = memory
		var teammate: bool = state.landlord_seat != PLAYER and state.landlord_seat != seat
		_configs[seat].effort = 1.0
		# Loyalty is for the player's teammate only: it never throws a game (ADR 0025).
		_configs[seat].loyalty = 0.0
		if teammate:
			var warmth: float = state.memory.warmth(state.table[seat], DEFAULT_MEMORY)
			_configs[seat].loyalty = warmth * DEFAULT_MEMORY.loyal_cooperation
			_configs[seat].effort = FreeRiding.effort(
				share, _configs[seat].team_cooperation(), DEFAULT_FREE_RIDE
			)


## Ends the run when a meter has reached death. Every caller sits at a state that may
## move to the run's end.
## A run that dies mid-Set still remembers that Set: the round in play is folded into
## the Set's summary, and the summary into the village's memory, as a finished Set's is.
func _remember_cut_short() -> void:
	# With no round in play the Set has ended, and its memory is already recorded.
	if _round == null or state.summaries.is_empty():
		return
	set_log.end_round(state, PLAYER)
	state.memory.record(state.summaries[-1])
	CorruptionEvents.close_quota(state, set_log.events(), _params.base_need)


func _end_if_dead() -> bool:
	if not RunMeters.dead(state, _meters):
		return false
	var meter: String = RunMeters.FAMINE
	if state.denunciation >= _meters.denunciation.death:
		meter = RunMeters.DENUNCIATION
	set_log.add(RunEvent.new(RunEvent.Type.RUN_DIED, PLAYER, 0, 0.0, meter))
	_remember_cut_short()
	_round = null
	_deal = null
	_stack.clear()
	_move(RunFlow.State.RUN_END, true)
	_awaiting = Awaiting.RUN_OVER
	return true


## Serves owed reeducation in place of the shop: the plot is emptied and one held
## Cadre, drawn on the events stream, is exchanged for one the player does not hold.
func _reeducate() -> void:
	_move(RunFlow.State.REEDUCATION)
	state.reeducation_due = false
	state.inventory.plot.clear()
	var change: PackedStringArray = Reeducation.change_cadre(
		state.inventory, pools.exchange(), state.streams.stream(RandomStreams.EVENTS)
	)
	state.cadre_memos.keep_only(state.inventory.cadres)
	set_log.add(RunEvent.new(RunEvent.Type.REEDUCATED, PLAYER, 0, 0.0, ">".join(change)))
	_awaiting = Awaiting.REEDUCATION


func _shop_command(command: Dictionary, act: Callable) -> Reason:
	if _awaiting != Awaiting.SHOP or open_envelope() != null:
		return Reason.NOT_AWAITED
	if act.call() != RunShop.Reason.OK:
		return Reason.ILLEGAL
	record.add(command)
	return Reason.OK


## Every move the loop makes is in the table, so a refusal is a bug. A checkpoint move
## marks the record before the autosave sees it.
func _move(to: RunFlow.State, checkpoint: bool = false) -> void:
	var reason: RunFlow.Reason = flow.move(to)
	assert(reason == RunFlow.Reason.OK, "Illegal run transition")
	state.phase = flow.state()
	if checkpoint:
		record.mark(state)
	if on_boundary.is_valid():
		on_boundary.call(self)
