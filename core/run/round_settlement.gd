class_name RoundSettlement
extends RefCounted
## What a round settles once its last card is played: the hooks at its end, the scores
## totalled and banked, the Commons split among the needs declared and their audit, and
## the Cadres and meters that answer them. The loop decides what comes next.

var _state: RunState
var _log: SetLog
var _stack: ModifierStack
var _table: SeatRules
var _meters: MeterTable
var _params: RunParams
var _configs: Array[BotConfig]
var _pools: RunPools
var _campaigns: RunCampaigns
var _debuffs: RunDebuffs


func _init(
	state: RunState,
	set_log: SetLog,
	stack: ModifierStack,
	table: SeatRules,
	meters: MeterTable,
	params: RunParams,
	configs: Array[BotConfig],
	pools: RunPools,
	campaigns: RunCampaigns,
	debuffs: RunDebuffs
) -> void:
	_state = state
	_log = set_log
	_stack = stack
	_table = table
	_meters = meters
	_params = params
	_configs = configs
	_pools = pools
	_campaigns = campaigns
	_debuffs = debuffs


## Banks the round just over: the hooks at its end, its scores totalled and paid, the
## Commons it pays into, and the meters its debuffs move.
func bank(round: RoundState, scoring: RoundScoring) -> void:
	var finish: RoundEvent.Finish = round.events()[-1].value as RoundEvent.Finish
	var winner: int = round.winner()
	var landlord: int = _state.landlord_seat
	var ending: RoundContext = RoundContext.new(landlord, winner, finish)
	ending.landlord_cards = round.remaining()[landlord]
	_stack.run_round_end(ending)
	_debuffs.ended(ending)
	# Before the round is scored, so the Quota's summary reads it as the round's (ADR 0032).
	if ending.famine_fall > 0:
		var logged: Array[RunEvent] = _log.events()
		var fall: int = ending.famine_fall
		RunMeters.lower(
			_state, RunMeters.CADRE_FAMINE, fall, _meters, _stack, _params, RunLoop.PLAYER, logged
		)
	var totals: PackedFloat64Array = RoundTotals.totals(
		scoring.scores(), landlord, winner, finish, _table.rules_for(landlord)
	)
	RunCadres.scale_commons(totals, landlord, ending.commons_scale)
	RunCadres.announce(_state, _log, RunLoop.PLAYER)
	_campaigns.settle(totals, landlord, winner)
	_debuffs.settle(totals, landlord)
	RoundBanking.bank(_state, totals, RunLoop.PLAYER, _log.events())
	for source: String in _debuffs.meter_sources:
		_raise(source)


## Splits the Commons among the needs declared, player_need the player's, audits each
## claim, and answers what the audit found.
func split(player_need: int) -> void:
	var faces: int = NeedAudit.faces(_state, _pools.audit, _stack)
	var caught: Array[int] = []
	var events: Array[RunEvent] = _log.events()
	# A claim reads the meters as they stand when it is made (ADR 0043).
	var shifted: Array[int] = TraitShifts.apply(_state, _configs, RunDefaults.VILLAGE, _meters)
	var claims_from: int = events.size()
	if RoundBanking.split(
		_state,
		RunLoop.PLAYER,
		player_need,
		_configs,
		_params,
		events,
		faces,
		caught,
		_pools.audit,
		_debuffs.cut
	):
		_raise(RunMeters.COMMONS_SHORTFALL)
	TraitShifts.note_claims(_state, shifted, events, claims_from, _params.base_need)
	for seat: int in caught:
		if seat == RunLoop.PLAYER:
			_raise(RunMeters.CAUGHT_LIE)
		else:
			_denounce_villager(seat)
	_settle_need(player_need, caught)


## The Cadres that answer the split and its audit (ADR 0032): coupons for caught lies, and
## Resentment lowered for an honest claim, which only a peasant makes.
func _settle_need(player_need: int, caught: Array[int]) -> void:
	var declared: int = player_need
	if _state.landlord_seat == RunLoop.PLAYER:
		declared = NeedContext.NOT_DECLARED
	var settled: NeedContext = RunCadres.settle_need(
		_stack, _state, RunLoop.PLAYER, declared, _params.base_need, caught
	)
	if settled.resentment_fall > 0:
		Resentment.lower(
			_state, settled.resentment_fall, Resentment.CADRE, RunDefaults.RESENTMENT, _log.events()
		)
	RunCadres.announce(_state, _log, RunLoop.PLAYER)


## A caught villager's own Denunciation rises by the caught-lie row, as the player's does.
func _denounce_villager(seat: int) -> void:
	var family_id: String = _state.table[seat]
	var before: int = _state.villager_denunciation.get(family_id, 0)
	var amount: int = _meters.source(RunMeters.CAUGHT_LIE).amount
	var after: int = clampi(before + amount, 0, _params.meter_max)
	_state.villager_denunciation[family_id] = after
	_log.add(RunEvent.new(RunEvent.Type.VILLAGER_DENOUNCED, seat, after - before, 0.0, family_id))


## Moves a meter by a source in the meter table. Callers check death at a boundary.
func _raise(source_id: String) -> void:
	RunMeters.apply(_state, source_id, _meters, _stack, _params, RunLoop.PLAYER, _log.events())
