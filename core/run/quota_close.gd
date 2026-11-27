class_name QuotaClose
extends RefCounted
## What closes a Quota once its last round is over: the Cadres that pay at its end, the
## reward or the Famine of a miss, the village's fates, what the village remembers and
## the corruption it leaves, and the Resentment and Denunciation the Quota charges. The
## loop then moves the run to the Set's end.

var _state: RunState
var _log: SetLog
var _stack: ModifierStack
var _meters: MeterTable
var _params: RunParams


func _init(
	state: RunState, set_log: SetLog, stack: ModifierStack, meters: MeterTable, params: RunParams
) -> void:
	_state = state
	_log = set_log
	_stack = stack
	_meters = meters
	_params = params


## Closes the Quota whose last round is over, against target, the target in force for
## it, with the rewards and steps sets pays.
func close(sets: SetConfig, target: float) -> void:
	var met: bool = _state.set_progress >= target
	var steps: int = sets.over_steps(_state.set_progress, target) if met else 0
	# Cadres that pay at a Quota's end are paid before the Quota is.
	var ending: SetContext = SetContext.new(_state.set_index, met)
	ending.coupons = _state.coupons
	ending.over_steps = steps
	_stack.run_set_end(ending)
	_state.coupons += ending.add_coupons
	RunCadres.announce(_state, _log, RunLoop.PLAYER)
	if met:
		_state.coupons += sets.reward(_state.set_type) + RunReforms.quota_coupons(_state)
		_overfulfil(sets, steps)
	else:
		var famine: int = _meters.source(RunMeters.MISSED_TARGET).amount
		RunMeters.apply_amount(
			_state,
			RunMeters.MISSED_TARGET,
			RunReforms.missed_famine(_state, famine),
			_meters,
			_stack,
			_params,
			RunLoop.PLAYER,
			_log.events()
		)
	# A family that starves is dead before reeducation could take it (ADR 0025).
	VillageFates.starve(_state, _meters.famine, RunDefaults.VILLAGE.starvations_per_year, _log)
	if met:
		VillageFates.depose(_state, RunPools.BOSSES.risen.id, _log)
	_reeducate_villagers()
	_state.memory.record(_state.summaries[-1])
	_record_style_and_risen()
	count_standing_by()
	CorruptionEvents.close_quota(_state, _log.events(), _params.base_need)
	var held: int = Resentment.private_cadres(_state.inventory.cadres, RunLoop.all_cadres())
	Resentment.add(
		_state,
		held * RunDefaults.RESENTMENT.private_cadre,
		Resentment.PRIVATE_CADRE,
		RunDefaults.RESENTMENT,
		_log.events()
	)
	Resentment.add(
		_state,
		steps * RunDefaults.RESENTMENT.overfulfilment,
		Resentment.OVERFULFILMENT,
		RunDefaults.RESENTMENT,
		_log.events()
	)
	# What a Cadre adds for the steps on top of that (Grain Speculator, ADR 0032).
	Resentment.add(
		_state, ending.add_resentment, Resentment.CADRE, RunDefaults.RESENTMENT, _log.events()
	)
	var owed: int = Resentment.denunciation(_state.resentment, RunDefaults.RESENTMENT)
	if owed > 0:
		RunMeters.apply_amount(
			_state,
			RunMeters.RESENTMENT,
			owed,
			_meters,
			_stack,
			_params,
			RunLoop.PLAYER,
			_log.events()
		)
	_stack.clear()
	_state.landlord_seat = Seats.NONE
	_state.deck_order.clear()
	_log.add(
		RunEvent.new(RunEvent.Type.SET_ENDED, Seats.NONE, 1 if met else 0, _state.set_progress)
	)
	if steps > 0:
		_log.add(RunEvent.new(RunEvent.Type.OVERFULFILLED, RunLoop.PLAYER, steps))


## A run that dies mid-Set still remembers that Set: the round in play is folded into
## the Set's summary, and the summary into the village's memory, as a finished Set's is.
func cut_short() -> void:
	_log.end_round(_state, RunLoop.PLAYER)
	_state.memory.record(_state.summaries[-1])
	CorruptionEvents.close_quota(_state, _log.events(), _params.base_need)


## A met Quota beaten by a step or more pays the bonus and raises the norm for every
## later Set. The steps are counted against the target in force for this Set, and stay
## in over_steps until the next Set starts, so RunLoop.target() still reads this Set's.
func _overfulfil(sets: SetConfig, steps: int) -> void:
	_state.coupons += sets.over_bonus(steps)
	_state.norm_steps += steps
	_state.over_steps = steps


## A family whose own Denunciation reached mid is sent to reeducation, and its count
## starts again.
func _reeducate_villagers() -> void:
	# In name order: a save sorts its keys, so insertion order would not survive one.
	var families: Array[String] = []
	families.assign(_state.villager_denunciation.keys())
	families.sort()
	for family_id: String in families:
		if _state.villager_denunciation[family_id] < _meters.denunciation.mid:
			continue
		var entry: RosterEntry = Roster.entry(_state, family_id)
		if entry == null or entry.status != RosterEntry.Status.ACTIVE:
			continue
		Roster.reeducate(_state, family_id, RunDefaults.VILLAGE)
		_state.villager_denunciation[family_id] = 0
		_log.add(
			RunEvent.new(RunEvent.Type.ROSTER_CHANGED, Seats.NONE, entry.status, 0.0, family_id)
		)


## Keeps the player's last few Sets of play, and marks a villager who held the landlord
## seat all Set as risen.
func _record_style_and_risen() -> void:
	_state.styles.append(PlayerStyle.from_events(_log.events(), RunLoop.PLAYER))
	while _state.styles.size() > RunPools.BOSSES.style_sets:
		_state.styles.pop_front()
	var holder: String = Bosses.full_set_holder(_log.events(), _state.table, RunLoop.PLAYER)
	if holder != Bosses.NO_FAMILY and not _state.risen.has(holder):
		_state.risen.append(holder)


## A Set the player never held the landlord's seat in lengthens a run of them, and past
## the grace each one costs Famine, more for each Set until the most (ADR 0031). The last
## free Set and every one that costs are logged, so the summary can say which it was.
## close() runs it; it is public for tests and tools that count Sets one at a time.
func count_standing_by() -> void:
	if YearClass.held_seat(_log.events(), RunLoop.PLAYER):
		_state.seatless_sets = 0
		return
	_state.seatless_sets += 1
	var steps: int = mini(_state.seatless_sets - _params.seat_grace_sets, _params.seat_max_steps)
	# Before the last free Set, or past it with no steps to pay (a most of 0).
	if steps < 0 or (steps == 0 and _state.seatless_sets > _params.seat_grace_sets):
		return
	var before: int = _state.famine
	if steps > 0:
		var each: int = _meters.source(RunMeters.STOOD_BY).amount
		var logged: Array[RunEvent] = _log.events()
		RunMeters.apply_amount(
			_state,
			RunMeters.STOOD_BY,
			steps * each,
			_meters,
			_stack,
			_params,
			RunLoop.PLAYER,
			logged
		)
	_log.add(
		RunEvent.new(RunEvent.Type.STOOD_BY, RunLoop.PLAYER, steps, float(_state.famine - before))
	)
