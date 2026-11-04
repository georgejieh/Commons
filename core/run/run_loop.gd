# gdlint: disable=max-file-lines
# Over 400 lines: the loop is the one command surface RunRecord replays, kept in one file.
class_name RunLoop
extends RefCounted
## Plays a run's Sets round by round: deal, bidding, plot swaps, play, scoring, banking,
## seat persistence, debuffs, meters and Set completion. The player sits in seat 0 and
## acts through commands; bots act in advance(). A Set is rebuilt from the RunState at
## its start plus the player's commands, which is how saves inside a Set resume.

enum Awaiting {NOTHING, PLAYER_BID, PLAYER_SWAP, PLAYER_PLAY, PLAYER_NEED, SET_OVER, SHOP, RUN_OVER}
enum Reason { OK, NOT_AWAITED, ILLEGAL }

const PLAYER: int = 0
const DEFAULT_PARAMS: RunParams = preload("res://data/run/default_run.tres")
const DEFAULT_POOL: DebuffPool = preload("res://data/run/debuff_pool.tres")
const DEFAULT_CADRES: CadrePool = preload("res://data/run/cadre_pool.tres")
const DEFAULT_SHOP: ShopParams = preload("res://data/run/default_shop.tres")

var state: RunState
var flow: RunFlow
var record: RunRecord = RunRecord.new()
## Called with the loop after every state move, for autosaves.
var on_boundary: Callable = Callable()
var set_log: SetLog = SetLog.new()
## The state store between Sets. Read it freely; buy and reroll through the commands.
var shop: RunShop

var _configs: Array[BotConfig]
var _sets: SetConfig
var _params: RunParams
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


## configs has one entry per seat; the player's entry is unused.
func _init(
	run_state: RunState,
	configs: Array[BotConfig],
	sets: SetConfig = SetConfig.new(),
	params: RunParams = DEFAULT_PARAMS,
	pool: Array[ModifierDef] = DEFAULT_POOL.debuffs
) -> void:
	state = run_state
	flow = RunFlow.new(run_state.phase)
	_configs = configs
	_sets = sets
	_params = params
	_pool = pool
	for definition: ModifierDef in pool + DEFAULT_CADRES.cadres:
		_pool_by_id[definition.id] = definition
	shop = RunShop.new(state, DEFAULT_SHOP, DEFAULT_CADRES.cadres)
	_table = SeatRules.new(_stack)
	_scoring = RoundScoring.new(HandLevels.new(Scorer.DEFAULT_PARAMS.max_level), _stack)


func awaiting() -> Awaiting:
	return _awaiting


func events() -> Array[RunEvent]:
	return set_log.events()


## The current round, for views. Null between rounds.
func round_state() -> RoundState:
	return _round


## The player's cards: the dealt hand before play, the round's hand during it.
func player_cards() -> Array[CardInstance]:
	if _round != null:
		return _round.view_for(PLAYER).own_cards
	var cards: Array[CardInstance] = []
	for card: CardInstance in _deal.hands[PLAYER].cards():
		cards.append(card.snapshot())
	return cards


## What the player's cards would score if played now, through the real scoring path.
func preview_play(card_ids: Array[int]) -> PlayPreview:
	return _scoring.preview(_round, PLAYER, card_ids)


## What the seat's rules and rank order are, for bots and hints.
func seat_table(seat: int) -> BotTable:
	_table.refresh()
	return BotTable.new(_table.rules_for(seat), _table.map_for(seat))


func target() -> float:
	return _sets.target(state.year, state.set_type)


## Starts the Set the state names. The Set's start is the save checkpoint.
func start_set() -> Reason:
	if not RunFlow.allows(flow.state(), RunFlow.State.SET_INTRO):
		return Reason.NOT_AWAITED
	record.mark(state)
	set_log.start_set(state, set_number())
	_move(RunFlow.State.SET_INTRO)
	state.round_index = 0
	state.set_progress = 0.0
	state.landlord_seat = Seats.NONE
	state.debuff_ladder = DebuffLadder.draw(
		_pool, state.set_type, _sets.max_rounds(), state.streams.stream(RandomStreams.DEBUFF)
	)
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
	_rebuild_modifiers()
	_seat = LandlordSeat.new()
	_seat.assign(state.landlord_seat)
	_deal_cards()
	if _seat.needs_bidding():
		_move(RunFlow.State.BIDDING)
		_bidding = Bidding.new(state.round_index % Seats.COUNT)
	else:
		_begin_play()
	advance()


## Runs bots until the player must act or the Set is over.
func advance() -> void:
	while _awaiting == Awaiting.NOTHING:
		if _bidding != null:
			_bot_bid()
		elif _round != null:
			_bot_play()
		else:
			return


func player_bid(claim: bool) -> Reason:
	if _awaiting != Awaiting.PLAYER_BID:
		return Reason.NOT_AWAITED
	_awaiting = Awaiting.NOTHING
	record.add({"type": "bid", "claim": claim})
	_record_bid(PLAYER, claim)
	advance()
	return Reason.OK


## Exchanges hand cards for plot cards, one for one, up to the round's swaps.
func player_swap(hand_ids: Array[int], plot_ids: Array[int]) -> Reason:
	if _awaiting != Awaiting.PLAYER_SWAP:
		return Reason.NOT_AWAITED
	if not PlotSwap.is_valid(
		_deal.hands[PLAYER], state.inventory, hand_ids, plot_ids, _params.swaps_per_round
	):
		return Reason.ILLEGAL
	record.add({"type": "swap", "hand": hand_ids.duplicate(), "plot": plot_ids.duplicate()})
	PlotSwap.apply(_deal.hands[PLAYER], state.inventory, hand_ids, plot_ids)
	set_log.add(RunEvent.new(RunEvent.Type.SWAPPED, PLAYER, hand_ids.size()))
	_awaiting = Awaiting.NOTHING
	_create_round()
	advance()
	return Reason.OK


## No cards is a pass.
func player_play(card_ids: Array[int]) -> Reason:
	if _awaiting != Awaiting.PLAYER_PLAY:
		return Reason.NOT_AWAITED
	if _round.apply(RoundAction.new(PLAYER, card_ids)) != RoundState.Reason.OK:
		return Reason.ILLEGAL
	record.add({"type": "play", "cards": card_ids.duplicate()})
	_awaiting = Awaiting.NOTHING
	_after_action()
	advance()
	return Reason.OK


func player_need(need: int) -> Reason:
	if _awaiting != Awaiting.PLAYER_NEED:
		return Reason.NOT_AWAITED
	record.add({"type": "need", "need": need})
	_awaiting = Awaiting.NOTHING
	_split_commons(need)
	advance()
	return Reason.OK


## Leaves a finished Set for the state store.
func open_shop() -> Reason:
	if _awaiting != Awaiting.SET_OVER:
		return Reason.NOT_AWAITED
	record.add({"type": "shop"})
	_move(RunFlow.State.SHOP)
	shop.open()
	_awaiting = Awaiting.SHOP
	return Reason.OK


func player_buy(slot: int) -> Reason:
	return _shop_command({"type": "buy", "slot": slot}, shop.buy.bind(slot))


func player_reroll() -> Reason:
	return _shop_command({"type": "reroll"}, shop.reroll)


## Moves past a finished Set or the shop: a Year's end after the boss, then the next Set.
## From a finished Set it passes through the shop without stopping.
func next_set() -> Reason:
	if _awaiting != Awaiting.SET_OVER and _awaiting != Awaiting.SHOP:
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
	state.set_index = (state.set_index + 1) % SetConfig.SETS_PER_YEAR
	state.set_type = state.set_index as RunState.SetType
	return start_set()


func years() -> int:
	return _sets.years()


## Counts Sets across the run from 0.
func set_number() -> int:
	return (state.year - 1) * SetConfig.SETS_PER_YEAR + state.set_index


## Cadres in slot order, then the ladder's debuffs so far, as the hook order says.
func _rebuild_modifiers() -> void:
	_stack.clear()
	for cadre_id: String in state.inventory.cadres:
		_stack.add(_pool_by_id[cadre_id], PLAYER)
	for round_index: int in range(1, state.round_index + 1):
		var id: String = state.debuff_ladder[round_index]
		if id == RunState.NO_DEBUFF:
			continue
		_stack.add(_pool_by_id[id], PLAYER)
		if round_index == state.round_index:
			set_log.add(RunEvent.new(RunEvent.Type.DEBUFF_ADDED, PLAYER, round_index, 0.0, id))


func _deal_cards() -> void:
	var cards: Array[CardInstance] = []
	for deck_id: int in Deck.generate():
		cards.append(CardInstance.from_deck_id(deck_id))
	_deal = Dealer.deal(cards, state.streams.stream(RandomStreams.DEAL))
	_stack.run_on_deal(DealContext.new(state.landlord_seat, _deal))
	set_log.add(RunEvent.new(RunEvent.Type.DEALT, Seats.NONE, state.round_index))


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
		_deal_cards()
		_bidding = Bidding.new(state.round_index % Seats.COUNT)
		return
	_seat.assign(_bidding.landlord())
	state.landlord_seat = _bidding.landlord()
	set_log.add(RunEvent.new(RunEvent.Type.LANDLORD_CHOSEN, _bidding.landlord(), _bidding.stake()))
	_bidding = null
	_begin_play()


func _begin_play() -> void:
	_move(RunFlow.State.ROUND_PLAY)
	if not state.inventory.plot.is_empty() and _params.swaps_per_round > 0:
		_awaiting = Awaiting.PLAYER_SWAP
		return
	_create_round()


func _create_round() -> void:
	_round = RoundState.new(_deal, state.landlord_seat, _table)
	_round_seen = 0
	_scoring.start(state.landlord_seat)
	_stack.run_round_start(RoundContext.new(state.landlord_seat, Seats.NONE, 0))
	_collect_round_events()


func _bot_play() -> void:
	var seat: int = _round.seat_to_act()
	if seat == PLAYER:
		_awaiting = Awaiting.PLAYER_PLAY
		return
	var legal: Array[Pattern] = _round.legal_moves()
	var play: BotPlay = Bot.decide_play(
		_round.view_for(seat), legal, seat_table(seat), _configs[seat], BotBudget.unlimited()
	)
	var action: RoundAction = RoundAction.new(seat)
	if not play.is_pass():
		action = _round.action_for(play.pattern)
	var offered: bool = (
		play.is_pass() or legal.any(func(move: Pattern) -> bool: return move.equals(play.pattern))
	)
	if not offered or _round.apply(action) != RoundState.Reason.OK:
		assert(false, "A bot chose an illegal action")
		_round.apply(_round.action_for(legal[0]))
	_after_action()


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
			var total: float = _scoring.score(event)
			set_log.add(RunEvent.new(RunEvent.Type.PLAY_SCORED, event.seat, 0, total))
	_round_seen = round_events.size()


func _finish_round() -> void:
	_move(RunFlow.State.ROUND_END)
	var finish: RoundEvent.Finish = _round.events()[-1].value as RoundEvent.Finish
	var winner: int = _round.winner()
	var landlord: int = state.landlord_seat
	_stack.run_round_end(RoundContext.new(landlord, winner, finish))
	var totals: PackedFloat64Array = RoundTotals.totals(
		_scoring.scores(), landlord, winner, finish, _table.rules_for(landlord)
	)
	RoundBanking.bank(state, totals, PLAYER, set_log.events())
	if landlord != PLAYER:
		_awaiting = Awaiting.PLAYER_NEED
		return
	_split_commons(0)


func _split_commons(player_need: int) -> void:
	RoundBanking.split(state, PLAYER, player_need, _configs, _params, set_log.events())
	_end_round()


func _end_round() -> void:
	set_log.end_round(state, PLAYER)
	var landlord_won: bool = _round.landlord_won()
	_seat.record_round(landlord_won)
	state.landlord_seat = _seat.holder()
	var kept: RunEvent.Type = RunEvent.Type.SEAT_KEPT if landlord_won else RunEvent.Type.SEAT_LOST
	set_log.add(RunEvent.new(kept, _round.landlord()))
	_round = null
	_deal = null
	state.round_index += 1
	if state.set_progress >= target() or state.round_index >= _sets.max_rounds():
		_end_set()
		return
	_start_round()


func _end_set() -> void:
	var met: bool = state.set_progress >= target()
	_stack.run_set_end(SetContext.new(state.set_index, met))
	if met:
		state.coupons += _sets.reward(state.set_type)
	else:
		RunMeters.raise_famine(
			state, _params.famine_on_missed_target, _stack, _params, PLAYER, set_log.events()
		)
	_stack.clear()
	state.landlord_seat = Seats.NONE
	set_log.add(
		RunEvent.new(RunEvent.Type.SET_ENDED, Seats.NONE, 1 if met else 0, state.set_progress)
	)
	_move(RunFlow.State.SET_END, true)
	_awaiting = Awaiting.SET_OVER


func _shop_command(command: Dictionary, act: Callable) -> Reason:
	if _awaiting != Awaiting.SHOP:
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
