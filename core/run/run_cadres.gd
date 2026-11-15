class_name RunCadres
extends RefCounted
## The run loop's side of what Cadres keep and do across the run (ADR 0021): the turn
## each real play or pass hands them, the Commons a round end may scale, the rank a
## purchase saves, and the log line for each Cadre that fired, which the table shows on
## that Cadre's card.


## Runs the turn taken hook for a PLAYED or PASSED round event and pays the player the
## coupons it earned. The caller adds the Resentment it returns.
static func take_turn(
	stack: ModifierStack, state: RunState, event: RoundEvent, round_state: RoundState, player: int
) -> TurnContext:
	var pattern: Pattern = event.pattern if event.type == RoundEvent.Type.PLAYED else null
	var turn: TurnContext = TurnContext.new(
		event.seat, round_state.landlord(), pattern, round_state.remaining()[event.seat], player
	)
	stack.run_turn_taken(turn)
	state.coupons += turn.coupons
	return turn


## Multiplies the peasants' round totals before they fill the Commons, so the ledger and
## the pool agree on what was scored.
static func scale_commons(totals: PackedFloat64Array, landlord: int, scale: float) -> void:
	if is_equal_approx(scale, 1.0):
		return
	for seat: int in Seats.COUNT:
		if seat != landlord:
			totals[seat] = Scorer.clamp_score(totals[seat] * scale)


## Logs CADRE_FIRED for every held Cadre that fired since the last call: value is what it
## fired for, text its ID.
static func announce(state: RunState, set_log: SetLog, player: int) -> void:
	for cadre_id: String in state.inventory.cadres:
		if not state.cadre_memos.has(cadre_id):
			continue
		var memo: CadreMemo = state.cadre_memos.entry(cadre_id)
		if memo.fired:
			set_log.add(
				RunEvent.new(RunEvent.Type.CADRE_FIRED, player, memo.take_fired(), 0.0, cadre_id)
			)


## True when a purchase may go ahead with this rank: any rank, or none, for a Cadre that
## needs no pick; a rank from 3 to 2 for one that does.
static func rank_fits(definition: ModifierDef, rank: int) -> bool:
	if definition == null or not definition.needs_rank:
		return true
	return rank >= Ranks.THREE and rank <= Ranks.TWO


## A Cadre was bought: its state starts fresh, with the rank picked for it.
static func bought(state: RunState, definition: ModifierDef, rank: int) -> void:
	var memo: CadreMemo = state.cadre_memos.reset(definition.id)
	if definition.needs_rank:
		memo.put(CadreMemo.RANK, rank)
