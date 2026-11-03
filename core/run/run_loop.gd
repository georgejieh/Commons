class_name RunLoop
extends RefCounted
## Plays a run's Sets round by round: deal, bidding, plot swaps, play, scoring, banking,
## seat persistence, debuffs, meters and Set completion. The player sits in seat 0 and
## acts through commands; bots act in advance(). A round is rebuilt from the RunState
## at its start plus the player's commands, which is how mid-round saves resume.

enum Awaiting { NOTHING, PLAYER_BID, PLAYER_SWAP, PLAYER_PLAY, PLAYER_NEED, SET_OVER, RUN_OVER }
enum Reason { OK, NOT_AWAITED, ILLEGAL }

const PLAYER: int = 0
const DEFAULT_PARAMS: RunParams = preload("res://data/run/default_run.tres")
const DEFAULT_POOL: DebuffPool = preload("res://data/run/debuff_pool.tres")

var state: RunState
var flow: RunFlow
var record: RunRecord = RunRecord.new()
## Called after every state move, for autosaves.
var on_boundary: Callable = Callable()

var _configs: Array[BotConfig]
var _sets: SetConfig
var _params: RunParams
var _pool: Array[ModifierDef]
var _pool_by_id: Dictionary[String, ModifierDef] = {}
var _stack: ModifierStack = ModifierStack.new()
var _table: SeatRules
var _seat: LandlordSeat = LandlordSeat.new()
var _levels: HandLevels = HandLevels.new(Scorer.DEFAULT_PARAMS.max_level)
var _events: Array[RunEvent] = []
var _awaiting: Awaiting = Awaiting.NOTHING
var _deal: DealResult
var _bidding: Bidding
var _round: RoundState
var _round_seen: int = 0
var _scores: PackedFloat64Array = PackedFloat64Array()


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
	for definition: ModifierDef in pool:
		_pool_by_id[definition.id] = definition
	_table = SeatRules.new(_stack)
	record.mark(state)


func awaiting() -> Awaiting:
	return _awaiting


func events() -> Array[RunEvent]:
	return _events


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


func player_counts() -> PackedByteArray:
	return _deal.hands[PLAYER].counts()


## What the seat's rules and rank order are, for bots and hints.
func seat_table(seat: int) -> BotTable:
	_table.refresh()
	return BotTable.new(_table.rules_for(seat), _table.map_for(seat))


func target() -> float:
	return _sets.target(state.year, state.set_type)


func start_set() -> void:
	_move(RunFlow.State.SET_INTRO)
	state.round_index = 0
	state.set_progress = 0.0
	state.landlord_seat = Seats.NONE
	state.debuff_ladder = DebuffLadder.draw(
		_pool, state.set_type, _sets.max_rounds(), state.streams.stream(RandomStreams.DEBUFF)
	)
	var ladder_text: String = ",".join(state.debuff_ladder.slice(1))
	_events.append(
		RunEvent.new(RunEvent.Type.SET_STARTED, Seats.NONE, set_number(), target(), ladder_text)
	)
	start_round()


## Picks up at a checkpoint: past a Set or the run, or at a round's start.
func resume_at_checkpoint() -> void:
	match state.phase:
		RunFlow.State.RUN_START:
			start_set()
		RunFlow.State.SET_END:
			_awaiting = Awaiting.SET_OVER
		RunFlow.State.RUN_END:
			_awaiting = Awaiting.RUN_OVER
		_:
			start_round()


## Starts the round state.round_index names, from the RunState alone.
func start_round() -> void:
	record.mark(state)
	_rebuild_debuffs()
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
	_events.append(RunEvent.new(RunEvent.Type.SWAPPED, PLAYER, hand_ids.size()))
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


## Moves past a finished Set: the shop, a Year's end after the boss, then the next Set.
func next_set() -> Reason:
	if _awaiting != Awaiting.SET_OVER:
		return Reason.NOT_AWAITED
	_awaiting = Awaiting.NOTHING
	_move(RunFlow.State.SHOP)
	if state.set_type == RunState.SetType.BOSS:
		_move(RunFlow.State.YEAR_END)
		if state.year == _sets.years():
			_move(RunFlow.State.RUN_END)
			record.mark(state)
			_awaiting = Awaiting.RUN_OVER
			return Reason.OK
		state.year += 1
	state.set_index = (state.set_index + 1) % SetConfig.SETS_PER_YEAR
	state.set_type = state.set_index as RunState.SetType
	start_set()
	return Reason.OK


## Counts Sets across the run from 0.
func set_number() -> int:
	return (state.year - 1) * SetConfig.SETS_PER_YEAR + state.set_index


func _rebuild_debuffs() -> void:
	for entry: ActiveModifier in _stack.ordered_entries():
		_stack.remove(entry)
	for round_index: int in range(1, state.round_index + 1):
		var id: String = state.debuff_ladder[round_index]
		if id == RunState.NO_DEBUFF:
			continue
		_stack.add(_pool_by_id[id], PLAYER)
		if round_index == state.round_index:
			_events.append(RunEvent.new(RunEvent.Type.DEBUFF_ADDED, PLAYER, round_index, 0.0, id))


func _deal_cards() -> void:
	var cards: Array[CardInstance] = []
	for deck_id: int in Deck.generate():
		cards.append(CardInstance.from_deck_id(deck_id))
	_deal = Dealer.deal(cards, state.streams.stream(RandomStreams.DEAL))
	_stack.run_on_deal(DealContext.new(state.landlord_seat, _deal))
	_events.append(RunEvent.new(RunEvent.Type.DEALT, Seats.NONE, state.round_index))


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
	_events.append(RunEvent.new(RunEvent.Type.BID, seat, 1 if claim else 0))
	if _bidding.phase() != Bidding.Phase.DONE:
		return
	if _bidding.needs_redeal():
		_events.append(RunEvent.new(RunEvent.Type.REDEALT))
		_move(RunFlow.State.BIDDING)
		_deal_cards()
		_bidding = Bidding.new(state.round_index % Seats.COUNT)
		return
	_seat.assign(_bidding.landlord())
	state.landlord_seat = _bidding.landlord()
	_events.append(
		RunEvent.new(RunEvent.Type.LANDLORD_CHOSEN, _bidding.landlord(), _bidding.stake())
	)
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
	_scores = PackedFloat64Array()
	_scores.resize(Seats.COUNT)
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
	var reason: RoundState.Reason = RoundState.Reason.DOES_NOT_BEAT
	if SelfPlay.is_offered(play, legal):
		reason = _round.apply(action)
	assert(reason == RoundState.Reason.OK, "A bot chose an illegal action")
	_after_action()


func _after_action() -> void:
	_collect_round_events()
	if _round.is_over():
		_finish_round()


func _collect_round_events() -> void:
	var round_events: Array[RoundEvent] = _round.events()
	for index: int in range(_round_seen, round_events.size()):
		var event: RoundEvent = round_events[index]
		_events.append(RunEvent.wrap(event))
		if event.type == RoundEvent.Type.PLAYED:
			var total: float = RoundTotals.play_score(event, _levels, state.landlord_seat, _stack)
			_scores[event.seat] += total
			_events.append(RunEvent.new(RunEvent.Type.PLAY_SCORED, event.seat, 0, total))
	_round_seen = round_events.size()


func _finish_round() -> void:
	_move(RunFlow.State.ROUND_END)
	var finish: RoundEvent.Finish = _round.events()[-1].value as RoundEvent.Finish
	var winner: int = _round.winner()
	var landlord: int = state.landlord_seat
	_stack.run_round_end(RoundContext.new(landlord, winner, finish))
	var totals: PackedFloat64Array = RoundTotals.totals(
		_scores, landlord, winner, finish, _table.rules_for(landlord)
	)
	for seat: int in Seats.COUNT:
		_events.append(RunEvent.new(RunEvent.Type.ROUND_SCORED, seat, 0, totals[seat]))
	RoundBanking.bank(state, totals, PLAYER, _events)
	if landlord != PLAYER:
		_awaiting = Awaiting.PLAYER_NEED
		return
	_split_commons(0)


func _split_commons(player_need: int) -> void:
	RoundBanking.split(state, PLAYER, player_need, _configs, _params, _events)
	_end_round()


func _end_round() -> void:
	var landlord_won: bool = _round.landlord_won()
	_seat.record_round(landlord_won)
	state.landlord_seat = _seat.holder()
	var kept: RunEvent.Type = RunEvent.Type.SEAT_KEPT if landlord_won else RunEvent.Type.SEAT_LOST
	_events.append(RunEvent.new(kept, _round.landlord()))
	_round = null
	_deal = null
	state.round_index += 1
	if state.set_progress >= target() or state.round_index >= _sets.max_rounds():
		_end_set()
		return
	start_round()


func _end_set() -> void:
	var met: bool = state.set_progress >= target()
	_move(RunFlow.State.SET_END)
	_stack.run_set_end(SetContext.new(state.set_index, met))
	if met:
		state.coupons += _sets.reward(state.set_type)
	else:
		RunMeters.raise_famine(
			state, _params.famine_on_missed_target, _stack, _params, PLAYER, _events
		)
	for entry: ActiveModifier in _stack.ordered_entries():
		_stack.remove(entry)
	state.landlord_seat = Seats.NONE
	_events.append(
		RunEvent.new(RunEvent.Type.SET_ENDED, Seats.NONE, 1 if met else 0, state.set_progress)
	)
	record.mark(state)
	_awaiting = Awaiting.SET_OVER


## Every move the loop makes is in the table, so a refusal is a bug.
func _move(to: RunFlow.State) -> void:
	var reason: RunFlow.Reason = flow.move(to)
	assert(reason == RunFlow.Reason.OK, "Illegal run transition")
	state.phase = flow.state()
	if on_boundary.is_valid():
		on_boundary.call()
