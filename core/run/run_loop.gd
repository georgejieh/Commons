# gdlint: disable=max-file-lines,max-public-methods
# Over 400 lines and 20 public methods: the run's state machine and the command surface
# RunRecord replays: each command's gate and record, and the round in play, whose deal,
# bidding and plays move the run between phases and are read here.
class_name RunLoop
extends RefCounted
## Plays a run's Sets round by round: deal, bidding, plot swaps, play, scoring, banking,
## seat persistence, debuffs, meters and Set completion. The player sits in seat 0 and
## acts through commands; bots act in advance(). A Set is rebuilt from the RunState at
## its start plus the player's commands, which is how saves inside a Set resume. What
## closes a round (RoundSettlement) and a Quota (QuotaClose), the shops (RunShopVisit) and who
## sits at the table (RunSeating) are parts of their own: the loop owns every gate and
## every move, and calls them.

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
	## A searching villager's play is being decided outside the loop (ADR 0030): read what the
	## search needs from search_request() and hand the play in with villager_play().
	VILLAGER_SEARCH,
}
enum Reason { OK, NOT_AWAITED, ILLEGAL }

const PLAYER: int = Seats.PLAYER
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
## The shops between Sets, and what each purchase there does. Read its counters freely;
## buy, sell and reroll through the commands.
var visit: RunShopVisit
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
var _stack: ModifierStack = ModifierStack.new()
var _table: SeatRules
var _seat: LandlordSeat = LandlordSeat.new()
var _scoring: RoundScoring
var _surplus: SurplusPay = SurplusPay.new()
var _settlement: RoundSettlement
var _quota_close: QuotaClose
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
	params: RunParams = RunDefaults.PARAMS,
	pool: Array[ModifierDef] = RunPools.DEBUFFS.debuffs,
	meters: MeterTable = RunDefaults.METERS
) -> void:
	state = run_state
	flow = RunFlow.new(run_state.phase)
	_configs = configs
	pools = RunPools.new(run_state.identity)
	_sets = sets.under_stake(pools.stake)
	_params = params
	_meters = meters
	_pool = pool
	if run_state.identity.is_tutorial():
		tutorial = RunTutorial.new(RunTutorial.SCRIPT, configs)
		tutorial.on_fault = func() -> void: refused_bot_actions += 1
	_table = SeatRules.new(_stack)
	campaigns = RunCampaigns.new(state, _stack, _table, meters, params, set_log, PLAYER)
	campaigns.quota_target = target
	debuffs = RunDebuffs.new(state, _stack, set_log, PLAYER)
	_scoring = RoundScoring.new(state.hand_levels, _stack)
	visit = RunShopVisit.new(state, set_log, _stack, meters, params, pools, debuffs, tutorial)
	_settlement = RoundSettlement.new(
		state, set_log, _stack, _table, meters, params, _configs, pools, campaigns, debuffs
	)
	_quota_close = QuotaClose.new(state, set_log, _stack, meters, params)


## Every Cadre either shop sells: the collective ones and the private ones.
static func all_cadres() -> Array[ModifierDef]:
	return RunPools.STORE_CADRES.cadres + RunPools.MARKET_CADRES.cadres


## What the loop waits on now.
func awaiting() -> Awaiting:
	return _awaiting


## The current Set's log so far.
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


## The cards the round's deal set aside face up (ADR 0043), every seat's to see; none
## between deals.
func set_aside_cards() -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	if _deal != null:
		for card: CardInstance in _deal.set_aside:
			cards.append(card.snapshot())
	return cards


## The player's view of the round: the public view and their own cards, plus whatever
## their information upgrades reveal. Null between rounds.
func player_view() -> SeatView:
	if _round == null:
		return null
	var view: SeatView = _round.view_for(PLAYER)
	var info_flags: int = _info_flags()
	if info_flags != 0:
		view.info = InfoReveal.build(_round, PLAYER, info_flags, seat_table(PLAYER))
	return view


## What the player's information upgrades show while the landlord seat is bid for (ADR
## 0043), or null when nothing is bid for or they show nothing then. No bot reads it.
func bid_info() -> InfoView:
	if _bidding == null or _deal == null:
		return null
	return InfoReveal.bid_info(_deal, _info_flags())


func _info_flags() -> int:
	var held: Array[ModifierDef] = []
	for cadre_id: String in state.inventory.cadres:
		held.append(RunDefinitions.modifiers[cadre_id])
	return InfoReveal.flags(held)


## What the player's cards would score if played now, through the real scoring path, as
## reading when one is named (ADR 0029), else as their strongest reading.
func preview_play(card_ids: Array[int], reading: Pattern = null) -> PlayPreview:
	return _scoring.preview(_round, PLAYER, card_ids, reading)


## What the seat's rules and rank order are, for bots and hints.
func seat_table(seat: int) -> BotTable:
	_table.refresh()
	return BotTable.of_seat(_table, seat)


## The current Set's target: the curve's, any boss's change, then the norm in force for
## this Set, which leaves out what the Set itself earned once it is over and what a False
## Report raised it by in the Set (ADR 0032), then the family's file and the corrections
## in force (ADR 0022).
func target() -> float:
	var base: float = _sets.target(state.year, state.set_type)
	if state.boss_id != RunState.NO_BOSS:
		var boss: ModifierDef = RunDefinitions.modifiers[state.boss_id]
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
	RunSeating.seat_roster(state, _configs)
	set_log.start_set(state, state.set_number())
	_move(RunFlow.State.SET_INTRO)
	state.round_index = 0
	state.set_progress = 0.0
	state.over_steps = 0
	state.reported_steps = 0
	state.landlord_seat = Seats.NONE
	RunSeating.choose_boss(state, _configs, _sets.years(), set_log)
	var ladder_stream: RandomStream = state.streams.stream(RandomStreams.DEBUFF)
	state.debuff_ladder = DebuffLadder.draw(
		_pool, state.set_type, _sets.max_rounds(), ladder_stream, pools.ladder
	)
	state.slogan_type = RunDebuffs.draw_slogan(state.debuff_ladder, ladder_stream)
	var ladder_text: String = ",".join(state.debuff_ladder.slice(1))
	set_log.add(
		RunEvent.new(
			RunEvent.Type.SET_STARTED, Seats.NONE, state.set_number(), target(), ladder_text
		)
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
	rebuild_modifiers()
	_seat = LandlordSeat.new()
	_seat.assign(state.landlord_seat)
	_deal_cards()
	if _seat.needs_bidding():
		_move(RunFlow.State.BIDDING)
		_bidding = Bidding.new(_first_bidder())
		_show_kitty()
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


## Calls or grabs the landlord seat with claim true, or passes on it.
func player_bid(claim: bool) -> Reason:
	if _awaiting != Awaiting.PLAYER_BID:
		return Reason.NOT_AWAITED
	_awaiting = Awaiting.NOTHING
	record.add({"type": "bid", "claim": claim})
	# Calling an open seat is free. Taking it from a neighbour who holds it is resented.
	# It is charged before the bid is recorded: a grab can end the bidding and start the
	# round, and the villagers' grudge for that round must already count it.
	if claim and bid_holder() != Seats.NONE:
		_resent(RunDefaults.RESENTMENT.grab, Resentment.GRAB)
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


## Buys the state store's Campaign in slot.
func player_campaign_buy(slot: int) -> Reason:
	return _shop_command({"type": "campaign_buy", "slot": slot}, visit.campaign_buy.bind(slot))


## Buys the black market's Campaign in slot, which adds Resentment as any purchase there
## does.
func player_market_campaign(slot: int) -> Reason:
	var command: Dictionary = {"type": "market_campaign", "slot": slot}
	return _shop_command(command, visit.market_campaign.bind(slot))


## Enacts the state store's Reform: it lasts the rest of the run (ADR 0021).
func player_reform(slot: int) -> Reason:
	return _shop_command({"type": "reform", "slot": slot}, visit.reform.bind(slot))


## Buys the state store's envelope, which opens it at once (ADR 0021). Until the player
## keeps one of its items or nothing, every other shop command is refused.
func player_envelope_buy(slot: int) -> Reason:
	return _shop_command({"type": "envelope_buy", "slot": slot}, visit.envelope_buy.bind(slot))


## Buys the black market's Parcel: a private purchase, resented when it is bought.
func player_market_envelope(slot: int) -> Reason:
	var command: Dictionary = {"type": "market_envelope", "slot": slot}
	return _shop_command(command, visit.market_envelope.bind(slot))


## Keeps the open envelope's item at index, or nothing with EnvelopeCounter.NOTHING, and
## closes it. A card for the deck goes in place of the deck card in out (ADR 0042). A
## refused pick changes nothing and leaves it open.
func player_envelope_pick(index: int, out: int = Deck.NO_SLOT) -> Reason:
	var opened: EnvelopeCounter = visit.open_envelope()
	if _awaiting != Awaiting.SHOP or opened == null:
		return Reason.NOT_AWAITED
	if opened.pick(index, PLAYER, out) != RunShop.Reason.OK:
		return Reason.ILLEGAL
	var command: Dictionary = {"type": "envelope_pick", "index": index}
	if out != Deck.NO_SLOT:
		command["out"] = out
	record.add(command)
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
	var kept: Dictionary = RunCorrections.clamped(figures, _params, RunDefaults.RESENTMENT, books)
	record.add({"type": "books", "figures": kept})
	var correction: BooksCorrection = RunCorrections.apply(
		state,
		kept,
		target(),
		_meters,
		_params,
		RunDefaults.RESENTMENT,
		books,
		set_log.events(),
		PLAYER
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


## Declares the player's need from the Commons at the round's split.
func player_need(need: int) -> Reason:
	if _awaiting != Awaiting.PLAYER_NEED:
		return Reason.NOT_AWAITED
	record.add({"type": "need", "need": need})
	_awaiting = Awaiting.NOTHING
	_split_commons(need)
	advance()
	return Reason.OK


## Leaves a finished Set for the state store, or for reeducation when it is owed. The
## run's last Set has no shops after it: next_set() ends the run.
func open_shop() -> Reason:
	if _awaiting != Awaiting.SET_OVER or is_last_set():
		return Reason.NOT_AWAITED
	record.add({"type": "shop"})
	if state.reeducation_due:
		_move(RunFlow.State.REEDUCATION)
		visit.reeducate()
		_awaiting = Awaiting.REEDUCATION
		return Reason.OK
	_move(RunFlow.State.SHOP)
	visit.open()
	_awaiting = Awaiting.SHOP
	return Reason.OK


## Buys the state store's Cadre in slot.
func player_buy(slot: int) -> Reason:
	return _shop_command({"type": "buy", "slot": slot}, visit.buy.bind(slot))


## Rerolls the state store's Cadres.
func player_reroll() -> Reason:
	return _shop_command({"type": "reroll"}, visit.reroll)


## Issues a Directive from the state store: its hand types rise a level at once.
func player_directive(slot: int) -> Reason:
	return _shop_command({"type": "directive", "slot": slot}, visit.directive.bind(slot))


## Buys from the black market. Every purchase there is a private one, and adds
## Resentment. A Cadre that needs a rank is refused without one from 3 to 2 (ADR 0021).
func player_market_buy(slot: int, rank: int = Ranks.INVALID) -> Reason:
	var command: Dictionary = {"type": "market_buy", "slot": slot}
	if rank != Ranks.INVALID:
		command["rank"] = rank
	return _shop_command(command, visit.market_buy.bind(slot, rank))


## Sells the held Cadre at index back to the state store, or with at_market to the black
## market, for part of its price there (ADR 0040). It leaves the board and its saved state
## for good, and neither counter offers it again this visit. Nothing its purchase changed
## is given back, and the sale changes no meter. A Cadre a debuff holds stays.
func player_sell_cadre(index: int, at_market: bool = false) -> Reason:
	var command: Dictionary = {"type": "sell_cadre", "index": index, "market": at_market}
	return _shop_command(command, visit.sell_cadre.bind(index, at_market))


## Sells the held Campaign at index back to the state store, or the black market, as a
## Cadre is sold; neither counter offers it again this visit.
func player_sell_campaign(index: int, at_market: bool = false) -> Reason:
	var command: Dictionary = {"type": "sell_campaign", "index": index, "market": at_market}
	return _shop_command(command, visit.sell_campaign.bind(index, at_market))


## Marks the deck card with ID card_id at the state store's desk, or with at_market at the
## black market's, for the rest of the run (ADR 0041). The black market's stamps it as the
## player's and is a private purchase, which adds Resentment.
func player_mark_card(card_id: int, at_market: bool = false) -> Reason:
	var command: Dictionary = {"type": "mark_card", "card": card_id, "market": at_market}
	return _shop_command(command, visit.mark_card.bind(card_id, at_market))


## Buys the state store's card in slot for the communal deck, in place of the deck card
## in out, for the rest of the run (ADR 0042).
func player_deck_card(slot: int, out: int) -> Reason:
	var command: Dictionary = {"type": "deck_card", "slot": slot, "out": out}
	return _shop_command(command, visit.deck_card.bind(slot, out))


## Rerolls the black market's Cadres.
func player_market_reroll() -> Reason:
	return _shop_command({"type": "market_reroll"}, visit.market_reroll)


## Buys a card for the private plot at the black market: a private purchase too.
func player_plot_card(slot: int) -> Reason:
	return _shop_command({"type": "plot_card", "slot": slot}, visit.plot_card.bind(slot))


## Buys a private-plot upgrade at the black market: a private purchase like any other.
func player_upgrade(kind: String) -> Reason:
	return _shop_command({"type": "upgrade", "kind": kind}, visit.upgrade.bind(kind))


## Moves past the shops, reeducation or the run's last Set: a Year's end after the boss,
## then the next Set or the run's end. Any other finished Set goes to the shops first,
## through open_shop(), so a reeducation that is due is never passed by.
func next_set() -> Reason:
	if not [Awaiting.SET_OVER, Awaiting.SHOP, Awaiting.REEDUCATION].has(_awaiting):
		return Reason.NOT_AWAITED
	if _awaiting == Awaiting.SET_OVER and not is_last_set():
		return Reason.NOT_AWAITED
	# An open envelope is answered before the shops are left.
	if visit.open_envelope() != null:
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


## Leaves the shops for the next Set, or the run's end.
func leave_store() -> Reason:
	if _awaiting != Awaiting.SHOP:
		return Reason.NOT_AWAITED
	return next_set()


## Leaves reeducation for the next Set, or the run's end.
func leave_reeducation() -> Reason:
	if _awaiting != Awaiting.REEDUCATION:
		return Reason.NOT_AWAITED
	return next_set()


## True while the Set in play, or the one just ended, is the run's last: its last Year's
## boss Set.
func is_last_set() -> bool:
	return state.set_type == RunState.SetType.BOSS and state.year == _sets.years()


## The Sets this run plays, its stake's numbers in them.
func sets() -> SetConfig:
	return _sets


## The round's deal as it was dealt, for tests and tools that check what was dealt.
func deal() -> DealResult:
	return _deal


## Builds the modifier stack again from what the state holds: Cadres in slot order, then
## the ladder's debuffs so far, as the hook order says. The loop runs it whenever the
## inventory, the Reforms or the ladder change.
func rebuild_modifiers() -> void:
	_stack.clear()
	for cadre_id: String in state.inventory.cadres:
		_stack.add(RunDefinitions.modifiers[cadre_id], PLAYER, state.cadre_memos.entry(cadre_id))
	# A Reform's rule for the player's seat, such as Industrialization's bigger bombs
	# (ADR 0029, ADR 0039).
	for rule: ActiveModifier in RunReforms.table_rules(state, PLAYER):
		_stack.add_entry(rule)
	for round_index: int in range(1, state.round_index + 1):
		var id: String = state.debuff_ladder[round_index]
		if id == RunState.NO_DEBUFF:
			continue
		var entry: ActiveModifier = _stack.add(RunDefinitions.modifiers[id], PLAYER)
		if round_index == state.round_index:
			campaigns.flags.round_debuff = entry
			set_log.add(RunEvent.new(RunEvent.Type.DEBUFF_ADDED, PLAYER, round_index, 0.0, id))
	if state.boss_id != RunState.NO_BOSS:
		_stack.add(RunDefinitions.modifiers[state.boss_id], PLAYER)
	debuffs.rebuilt()


## Shuffles a fresh deck, or under Unplanned Economy cuts the one the last round left
## (DeckOrder). Either way it is the run's deck, as the state store's exchanges left it
## (ADR 0042), with the marks saved on its cards back on (ADR 0021). The arrival deals its
## authored decks (ADR 0026).
func _deal_cards() -> void:
	var stream: RandomStream = state.streams.stream(RandomStreams.DEAL)
	if tutorial != null:
		_deal = tutorial.deal(state.round_index, pools.audit, state.deck)
	elif RunReforms.gathers_deck(state) and not state.deck_order.is_empty():
		_deal = DeckOrder.deal(state.deck_order, state.deck, state.card_marks, stream)
	else:
		var cards: Array[CardInstance] = state.deck.cards()
		state.card_marks.apply(cards)
		_deal = Dealer.deal(cards, stream)
	_stack.run_on_deal(DealContext.new(state.landlord_seat, _deal, stream, state.year))
	set_log.add(RunEvent.new(RunEvent.Type.DEALT, Seats.NONE, state.round_index))
	if not _deal.set_aside.is_empty():
		var aside: String = _ids_text(_deal.set_aside)
		set_log.add(RunEvent.new(RunEvent.Type.CARDS_SET_ASIDE, PLAYER, 0, 0.0, aside))
	# Mass Line's rank is drawn after the deal on its stream, so the deal is unchanged and
	# every seat knows it before the bid (ADR 0029). It is the player's alone (ADR 0039).
	for _rank: int in RunReforms.wild_ranks_per_round(state):
		if RunWild.has_room(state):
			var rank: int = RunWild.add(state, stream)
			set_log.add(RunWild.event(state, rank))
			_table.set_wild_ranks(state.wild_ranks, PLAYER)


## Logs the kitty the player's information upgrade shows them before the bid (ADR 0043).
func _show_kitty() -> void:
	var info: InfoView = bid_info()
	if info != null and not info.kitty.is_empty():
		var kitty: String = _ids_text(info.kitty)
		set_log.add(RunEvent.new(RunEvent.Type.KITTY_SEEN, PLAYER, 0, 0.0, kitty))


static func _ids_text(cards: Array[CardInstance]) -> String:
	var ids: PackedStringArray = []
	for card: CardInstance in cards:
		ids.append(str(card.id()))
	return ",".join(ids)


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
		_show_kitty()
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
			if visit.open_envelope() == null:
				return CampaignContext.Moment.SHOP
	return CampaignContext.Moment.ELSEWHERE


func _create_round() -> void:
	# Families play the round by their traits as the meters stand at its start (ADR 0043).
	TraitShifts.apply(state, _configs, RunDefaults.VILLAGE, _meters)
	RunSeating.aim_grudges(state, _configs)
	# The round's wild ranks (ADR 0029), none unless an item drew them. Every item that
	# draws one is the player's, so they are the player's seat's alone (ADR 0039).
	_table.set_wild_ranks(state.wild_ranks, PLAYER)
	_round = RoundState.new(_deal, state.landlord_seat, _table)
	_round_seen = 0
	_scoring.start(state.landlord_seat, state.year)
	_surplus.start_round()
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


## What the search for the villager the loop stands still for reads (ADR 0030), or null
## while it waits on anything else. The search may read it on any thread.
func search_request() -> SearchRequest:
	return _request


## Takes the searched play of the villager the loop stands still for, and plays on (ADR 0030).
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
						* RunDefaults.RESENTMENT.stamped_card
					),
					Resentment.STAMPED_CARD
				)
			var scored: RunEvent = RunEvent.new(RunEvent.Type.PLAY_SCORED, event.seat, 0, total)
			scored.grain = _scoring.last_grain()
			scored.rate = _scoring.last_rate()
			scored.zeal = _scoring.last_zeal()
			scored.steps = _scoring.last_steps()
			if event.seat == PLAYER:
				var surplus: Array[int] = _scoring.last_surplus_cards()
				scored.steps.append_array(_surplus.pay(state, surplus, Scorer.DEFAULT_PARAMS))
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
	var landlord: int = state.landlord_seat
	_settlement.bank(_round, _scoring)
	if landlord != PLAYER:
		_awaiting = Awaiting.PLAYER_NEED
		return
	_split_commons(0)


## The chance that each declared need is audited at this round's split: the audit faces
## over the die's sides.
func audit_chance() -> float:
	return NeedAudit.chance(state, pools.audit, _stack)


func _split_commons(player_need: int) -> void:
	_settlement.split(player_need)
	if _end_if_dead():
		return
	_end_round()


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
	_table.set_wild_ranks(state.wild_ranks, PLAYER)
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
	_quota_close.close(_sets, target())
	_move(RunFlow.State.SET_END, true)
	_awaiting = Awaiting.SET_OVER
	_end_if_dead()


func _resent(amount: int, cause: String) -> void:
	if amount != 0:
		Resentment.add(state, amount, cause, RunDefaults.RESENTMENT, set_log.events())


## Ends the run when a meter has reached death. Every caller sits at a state that may
## move to the run's end.
func _end_if_dead() -> bool:
	if not RunMeters.dead(state, _meters):
		return false
	var meter: String = RunMeters.FAMINE
	if state.denunciation >= _meters.denunciation.death:
		meter = RunMeters.DENUNCIATION
	set_log.add(RunEvent.new(RunEvent.Type.RUN_DIED, PLAYER, 0, 0.0, meter))
	# With no round in play the Set has ended, and its memory is already recorded.
	if _round != null and not state.summaries.is_empty():
		_quota_close.cut_short()
	_round = null
	_deal = null
	_stack.clear()
	_move(RunFlow.State.RUN_END, true)
	_awaiting = Awaiting.RUN_OVER
	return true


## Runs a shop command while the shops wait on the player and no envelope is open, and
## records it when act, which returns whether it was done, did it.
func _shop_command(command: Dictionary, act: Callable) -> Reason:
	if _awaiting != Awaiting.SHOP or visit.open_envelope() != null:
		return Reason.NOT_AWAITED
	if not act.call():
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
