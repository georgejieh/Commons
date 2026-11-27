class_name RunDebuffs
extends RefCounted
## What the debuffs of ADR 0023 do beyond their hooks, kept beside RunLoop as RunCampaigns
## is: the Slogan's hand type drawn with the ladder and bound to its effect, Cadres
## confiscated for a round, cards moved before play logged, plot cards seized, the
## round's plot swap cap, what is taken from the player's bank, the meter rows a lost
## round raises, and the Cadres Short Supply keeps off the next state store. What it holds
## lasts one round; a replay of the Set's commands builds it again.

## The ID of the Slogan debuff, whose hand type is drawn with the ladder.
const SLOGAN_ID: String = "slogan_of_the_week"

## The round's cap on plot swaps, or RoundContext.NO_CAP.
var swap_cap: int = RoundContext.NO_CAP
## What debuffs take from the player's bank this round, set at the round's end.
var cut: BankCut = BankCut.new()
## Meter table rows the round's end raises.
var meter_sources: Array[String] = []
## The Cadres left out of this round.
var confiscated: Array[ActiveModifier] = []

var _state: RunState
var _stack: ModifierStack
var _log: SetLog
var _player: int


func _init(state: RunState, stack: ModifierStack, set_log: SetLog, player: int) -> void:
	_state = state
	_stack = stack
	_log = set_log
	_player = player


## The hand type a newly drawn ladder's Slogan names, drawn on the ladder's stream after
## the ladder's own draws, or RunState.NO_SLOGAN when the ladder has none.
static func draw_slogan(ladder: Array[String], stream: RandomStream) -> int:
	if not ladder.has(SLOGAN_ID):
		return RunState.NO_SLOGAN
	return SloganEffect.draw(stream)


## Cadres Short Supply keeps off the state store visit after a Quota: every debuff that
## came into force in it runs the shop open hook.
static func store_cut(
	state: RunState, definitions: Dictionary[String, ModifierDef], player: int
) -> int:
	var stack: ModifierStack = ModifierStack.new()
	var reached: int = mini(state.round_index, state.debuff_ladder.size())
	for round_index: int in range(1, reached):
		var debuff_id: String = state.debuff_ladder[round_index]
		if debuff_id != RunState.NO_DEBUFF:
			stack.add(definitions[debuff_id], player)
	var context: ShopContext = ShopContext.new(player)
	stack.run_shop_open(context)
	return context.cadre_cut


## After the round's stack is built: starts the round fresh, binds the Slogan's type, and
## leaves out the Cadres a Confiscation draws on the debuff stream.
func rebuilt() -> void:
	swap_cap = RoundContext.NO_CAP
	cut = BankCut.new()
	meter_sources.clear()
	confiscated.clear()
	var cadres: Array[ActiveModifier] = []
	var takers: Array[ConfiscationEffect] = []
	for entry: ActiveModifier in _stack.ordered_entries():
		if entry.definition.kind == ModifierDef.Kind.CADRE:
			cadres.append(entry)
		if entry.effect is SloganEffect:
			entry.effect.parameters[SloganEffect.TYPE] = _state.slogan_type
		if entry.effect is ConfiscationEffect:
			takers.append(entry.effect as ConfiscationEffect)
	var stream: RandomStream = _state.streams.stream(RandomStreams.DEBUFF)
	for taker: ConfiscationEffect in takers:
		if cadres.is_empty():
			return
		for slot: int in taker.choose(cadres.size(), stream):
			_confiscate(cadres[slot], slot)


## The round start hook's context: the round after the kitty, its rules, the deal stream
## and the debuff that came into force this round.
func round_context(
	round_state: RoundState, table: SeatRules, arrived: ActiveModifier
) -> RoundContext:
	var context: RoundContext = RoundContext.new(
		round_state.landlord(), Seats.NONE, RoundEvent.Finish.NORMAL
	)
	context.round_state = round_state
	context.table = table
	context.stream = _state.streams.stream(RandomStreams.DEAL)
	context.arrived = arrived.effect if arrived != null else null
	return context


## After the round start hook: keeps its swap cap, logs the cards it moved and destroys the
## plot cards it seized, drawn on the deal stream.
func started(context: RoundContext) -> void:
	swap_cap = context.swap_cap
	for moved: CardPass in context.moves:
		var ids: PackedStringArray = []
		for card_id: int in moved.card_ids:
			ids.append(str(card_id))
		_log.add(
			RunEvent.new(
				RunEvent.Type.CARDS_PASSED, moved.from_seat, moved.to_seat, 0.0, ",".join(ids)
			)
		)
	var plot: Array[CardInstance] = _state.inventory.plot
	for _card: int in context.seize_plot:
		if plot.is_empty():
			return
		var card: CardInstance = plot.pop_at(context.stream.next_int(0, plot.size() - 1))
		var named: String = "%d,%d" % [card.base_rank(), card.suit()]
		_log.add(RunEvent.new(RunEvent.Type.PLOT_SEIZED, _player, card.id(), 0.0, named))


## The plot swaps the round allows, from the run's own count.
func swaps(base: int) -> int:
	return base if swap_cap == RoundContext.NO_CAP else mini(base, swap_cap)


## After the round end hook: keeps what the round takes from the bank and the meters it
## raises.
func ended(context: RoundContext) -> void:
	cut = BankCut.new(context.bank_voided, context.tax_percent)
	meter_sources = context.meter_sources.duplicate()


## A landlord player's total is cut before it is banked, after any Campaign stake.
func settle(totals: PackedFloat64Array, landlord: int) -> void:
	if landlord == _player:
		totals[_player] = cut.apply(totals[_player], _player, _log.events())
		_log.flush()


## After a Campaign: when Appeal has turned the round's debuff off and it is a
## Confiscation, its Cadres are handed back at once, with the round's deal.
func after_campaign(round_debuff: ActiveModifier, deal: DealResult) -> void:
	if round_debuff == null or round_debuff.enabled or confiscated.is_empty():
		return
	if not round_debuff.effect is ConfiscationEffect:
		return
	for entry: ActiveModifier in confiscated:
		entry.effect.handed_back(deal)
	round_over()


## At the round's end: the Cadres a Confiscation left out of it are held again. A Quota
## that ends with this round then pays and resets them as it does the others, and the
## shops after it see them.
func round_over() -> void:
	for entry: ActiveModifier in confiscated:
		_stack.set_enabled(entry, true)
	confiscated.clear()


## The held Cadre IDs left out of this round.
func confiscated_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry: ActiveModifier in confiscated:
		ids.append(entry.definition.id)
	return ids


func _confiscate(entry: ActiveModifier, slot: int) -> void:
	_stack.set_enabled(entry, false)
	confiscated.append(entry)
	_log.add(RunEvent.new(RunEvent.Type.CADRE_CONFISCATED, _player, slot, 0.0, entry.definition.id))
