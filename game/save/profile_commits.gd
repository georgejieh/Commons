class_name ProfileCommits
extends RefCounted
## What a run writes to the profile, and only once each (ADR 0025, "Writing it once"). Two
## files cannot be written as one, so the profile remembers what it has taken: a finished
## run is recorded only while history does not hold its ID, and a Quota's memory is taken
## only when it is later than the last Quota taken from the same run. A crash between the
## run save and the profile then repeats nothing. Only a full run moves the generation,
## finished runs, wins, history, lineage and stake; any run that writes the profile keeps
## its memory. The lineage is taken the same way: the run that inherits it clears it in
## the write that makes it the next generation, so no run takes it twice, and a new one
## is written only with the finished run's record. Corruption goes with the memory: a
## full run's Quota adds its events once, and The Commons sets it to 0 with the run's
## record, after the last Quota, so nothing of that run outlives the reset (ADR 0025).


## A full run starting is the family's next generation. Writes the profile, and the
## generation and finished runs it started from into the run's identity, and the
## village's drift for that generation into both (ADR 0028), and the entries the family's
## file holds into the identity (ADR 0022). Returns the lineage the run
## inherits, {"kind", "values"}, taken out of the profile in the same write; a run that
## is not full inherits nothing and drifts nothing.
static func start_run(profile: SaveService, state: RunState) -> Dictionary:
	var data: ProfileData = Profile.read(profile)
	state.identity.finished_runs = data.finished_runs
	if not state.identity.is_full():
		return RunLineage.make(RunLineage.NONE)
	data.generation += 1
	state.identity.generation = data.generation
	# Every entry in the family's file raises the run's targets (ADR 0022).
	state.identity.file_entries = data.file.size()
	data.drift = VillageDrift.next(data.drift, data.generation, RunLoop.DEFAULT_VILLAGE)
	state.drift = VillageDrift.from_dict(data.drift.to_dict())
	var taken: Dictionary = RunLineage.make(data.lineage_kind, data.lineage_values.duplicate(true))
	data.lineage_kind = RunLineage.NONE
	data.lineage_values = {}
	Profile.write(profile, data)
	return taken


## Takes what the run has reached: the Quota just ended, and at the run's end its record.
## Returns true when it wrote the profile; false when there was nothing to take, or the
## write failed, which marks nothing as taken.
static func commit(profile: SaveService, state: RunState, finished: bool) -> bool:
	var data: ProfileData = Profile.read(profile)
	var changed: bool = _take_quota(data, state)
	if finished and state.identity.is_full() and not data.has_run(state.identity.id):
		_record(data, state)
		changed = true
	return changed and Profile.write(profile, data) == OK


## The run's Set count, from 0: the Quota now ending or just ended.
static func quota_number(state: RunState) -> int:
	return state.set_number()


static func _take_quota(data: ProfileData, state: RunState) -> bool:
	var quota: int = quota_number(state)
	if data.committed_run == state.identity.id and quota <= data.committed_quota:
		return false
	# A run already recorded has nothing more to give, so a reset is never undone.
	if data.has_run(state.identity.id):
		return false
	data.memory = VillageMemory.from_dict(state.memory.to_dict())
	if state.identity.is_full():
		data.corruption = CorruptionEvents.added(data.corruption, state.quota_corruption)
	data.committed_run = state.identity.id
	data.committed_quota = quota
	return true


static func _record(data: ProfileData, state: RunState) -> void:
	var outcome: String = Endings.outcome(state, RunLoop.DEFAULT_METERS)
	data.finished_runs += 1
	if outcome == Endings.THE_COMMONS:
		data.corruption = 0.0
	var landlord: bool = YearClass.is_landlord(state)
	if landlord and not Endings.is_death(outcome):
		data.landlord_endings += 1
	if not Endings.is_death(outcome):
		data.wins += 1
		# A win at the highest stake unlocked opens the next, up to the last.
		if state.identity.stake == data.stake:
			data.stake = mini(data.stake + 1, RunStakes.last())
	var left: Dictionary = RunLineage.left_by(state, RunLoop.DEFAULT_METERS, RunLoop.DEFAULT_MEMORY)
	data.lineage_kind = left["kind"]
	data.lineage_values = left["values"]
	var entry: HistoryEntry = HistoryEntry.new()
	entry.run_id = state.identity.id
	entry.generation = state.identity.generation
	entry.outcome = outcome
	entry.class_id = HistoryEntry.LANDLORD if landlord else HistoryEntry.PEASANT
	entry.year = state.year
	entry.household = state.identity.household
	entry.stake = state.identity.stake
	for found: RosterEntry in state.roster:
		if found.status == RosterEntry.Status.DEAD:
			entry.dead.append(Roster.name_key(RunLoop.DEFAULT_VILLAGE, found))
	data.add_history(entry)
