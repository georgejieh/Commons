class_name RunCampaigns
extends RefCounted
## The player's Campaigns (ADR 0021): one-use items held in RunInventory.consumables and
## spent at the moment each one's rule names. It checks a use, spends the Campaign and
## applies its effect, and holds what a Campaign keeps in force for the round, which
## starts fresh with every round. Bots never hold or use one.

const STORE_POOL: CampaignPool = preload("res://data/run/campaign_pool.tres")
const MARKET_POOL: CampaignPool = preload("res://data/run/market_campaign_pool.tres")

## What Campaigns hold in force this round.
var flags: CampaignRound = CampaignRound.new()

var _state: RunState
var _stack: ModifierStack
var _table: SeatRules
var _meters: MeterTable
var _params: RunParams
var _log: SetLog
var _player: int
var _definitions: Dictionary[String, CampaignDef] = {}


func _init(
	state: RunState,
	stack: ModifierStack,
	table: SeatRules,
	meters: MeterTable,
	params: RunParams,
	set_log: SetLog,
	player: int
) -> void:
	_state = state
	_stack = stack
	_table = table
	_meters = meters
	_params = params
	_log = set_log
	_player = player
	for definition: CampaignDef in all():
		_definitions[definition.id] = definition


## Every Campaign either shop sells.
static func all() -> Array[CampaignDef]:
	return STORE_POOL.campaigns + MARKET_POOL.campaigns


func definition(campaign_id: String) -> CampaignDef:
	return _definitions.get(campaign_id)


## A new round: nothing a Campaign held stays in force.
func start_round() -> void:
	flags = CampaignRound.new()


## Why the Campaign in slot cannot be used now, leaving the cards aside, or OK.
func availability(
	slot: int, moment: CampaignContext.Moment, round_state: RoundState
) -> CampaignEffect.Reason:
	var context: CampaignContext = _context(slot, [], moment, round_state)
	if context == null:
		return CampaignEffect.Reason.NO_SUCH_SLOT
	var reason: CampaignEffect.Reason = _timing(context)
	if reason != CampaignEffect.Reason.OK:
		return reason
	return CampaignRegistry.create(context.definition).check(context)


## Why using the Campaign in slot on these cards is refused now, or OK.
func check(
	slot: int, card_ids: Array[int], moment: CampaignContext.Moment, round_state: RoundState
) -> CampaignEffect.Reason:
	var context: CampaignContext = _context(slot, card_ids, moment, round_state)
	if context == null:
		return CampaignEffect.Reason.NO_SUCH_SLOT
	var reason: CampaignEffect.Reason = _timing(context)
	if reason == CampaignEffect.Reason.OK:
		reason = _cards(context)
	if reason == CampaignEffect.Reason.OK:
		reason = CampaignRegistry.create(context.definition).check(context)
	return reason


## Spends the Campaign in slot and applies it. The caller has checked the use.
func use(
	slot: int, card_ids: Array[int], moment: CampaignContext.Moment, round_state: RoundState
) -> void:
	var context: CampaignContext = _context(slot, card_ids, moment, round_state)
	_state.inventory.consumables.remove_at(slot)
	var used: RunEvent = RunEvent.new(
		RunEvent.Type.CAMPAIGN_USED, _player, slot, 0.0, context.definition.id
	)
	_log.add(used)
	CampaignRegistry.create(context.definition).apply(context)


## True when the player, about to wait for the first play as a peasant, holds a
## Campaign that could be used before it.
func wants_opening(round_state: RoundState) -> bool:
	if round_state.landlord() == _player:
		return false
	for slot: int in _state.inventory.consumables.size():
		var held: CampaignDef = definition(_state.inventory.consumables[slot])
		if held == null or held.when != CampaignDef.When.OPENING:
			continue
		var moment: CampaignContext.Moment = CampaignContext.Moment.OPENING
		if availability(slot, moment, round_state) == CampaignEffect.Reason.OK:
			return true
	return false


## After the player's play or pass: a Letter in force makes the next seat pass a play,
## and is spent for nothing on a pass or when the play ends the round.
func after_player_play(passed: bool, round_state: RoundState) -> void:
	if not flags.letter_armed:
		return
	flags.letter_armed = false
	var next: int = Seats.next(_player)
	if passed or round_state.is_over():
		_log.add(RunEvent.new(RunEvent.Type.LETTER_LAPSED, next))
	else:
		flags.forced_seat = next


## True, once, when seat must pass the play it is answering.
func forces_pass(seat: int, round_state: RoundState) -> bool:
	if seat != flags.forced_seat or round_state.current_play() == null:
		return false
	flags.forced_seat = Seats.NONE
	_log.add(RunEvent.new(RunEvent.Type.PASS_FORCED, seat))
	return true


## Overfulfillment settles the landlord player's total before it is banked.
func settle(totals: PackedFloat64Array, landlord: int, winner: int) -> void:
	if not flags.staked or landlord != _player:
		return
	var won: bool = winner == landlord
	totals[_player] = totals[_player] * flags.win_times if won else 0.0
	_log.add(RunEvent.new(RunEvent.Type.STAKE_SETTLED, _player, 1 if won else 0, totals[_player]))


func _context(
	slot: int, card_ids: Array[int], moment: CampaignContext.Moment, round_state: RoundState
) -> CampaignContext:
	var held: Array[String] = _state.inventory.consumables
	if slot < 0 or slot >= held.size() or definition(held[slot]) == null:
		return null
	var context: CampaignContext = CampaignContext.new()
	context.definition = definition(held[slot])
	context.state = _state
	context.round_state = round_state if moment != CampaignContext.Moment.SHOP else null
	context.table = _table
	context.stack = _stack
	context.meters = _meters
	context.params = _params
	context.flags = flags
	context.set_log = _log
	context.moment = moment
	context.card_ids = card_ids.duplicate()
	context.player = _player
	if context.round_state != null:
		context.opening = context.round_state.public_view().history.is_empty()
	return context


## The moment the Campaign's rule names.
func _timing(context: CampaignContext) -> CampaignEffect.Reason:
	var turn: bool = context.moment == CampaignContext.Moment.TURN
	match context.definition.when:
		CampaignDef.When.TURN:
			return CampaignEffect.Reason.OK if turn else CampaignEffect.Reason.NOT_NOW
		CampaignDef.When.TURN_OR_SHOP:
			var shop: bool = context.moment == CampaignContext.Moment.SHOP
			return CampaignEffect.Reason.OK if turn or shop else CampaignEffect.Reason.NOT_NOW
	if context.moment == CampaignContext.Moment.OPENING:
		return CampaignEffect.Reason.OK
	if turn:
		return CampaignEffect.Reason.OK if context.opening else CampaignEffect.Reason.PLAY_STARTED
	return CampaignEffect.Reason.NOT_NOW


## As many cards as the Campaign asks for, each held once.
func _cards(context: CampaignContext) -> CampaignEffect.Reason:
	var count: int = context.card_ids.size()
	if count < context.definition.min_cards or count > context.definition.max_cards:
		return CampaignEffect.Reason.CARD_COUNT
	var held: Dictionary[int, bool] = {}
	for card: CardInstance in context.hand():
		held[card.id()] = true
	var seen: Dictionary[int, bool] = {}
	for card_id: int in context.card_ids:
		if seen.has(card_id) or not held.has(card_id):
			return CampaignEffect.Reason.NOT_IN_HAND
		seen[card_id] = true
	return CampaignEffect.Reason.OK
