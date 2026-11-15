class_name ProfileCommits
extends RefCounted
## What a run writes to the profile, and only once each (ADR 0025, "Writing it once"). Two
## files cannot be written as one, so the profile remembers what it has taken: a finished
## run is recorded only while history does not hold its ID, and a Quota's memory is taken
## only when it is later than the last Quota taken from the same run. A crash between the
## run save and the profile then repeats nothing. Only a full run moves the generation,
## finished runs, wins and history; any run that writes the profile keeps its memory.


## A full run starting is the family's next generation. Writes the profile, and the
## generation and finished runs it started from into the run's identity.
static func start_run(profile: SaveService, state: RunState) -> void:
	var data: ProfileData = Profile.read(profile)
	state.identity.finished_runs = data.finished_runs
	if not state.identity.is_full():
		return
	data.generation += 1
	state.identity.generation = data.generation
	Profile.write(profile, data)


## Takes what the run has reached: the Quota just ended, and at the run's end its record.
## Returns true when it wrote the profile.
static func commit(profile: SaveService, state: RunState, finished: bool) -> bool:
	var data: ProfileData = Profile.read(profile)
	var changed: bool = _take_quota(data, state)
	if finished and state.identity.is_full() and not data.has_run(state.identity.id):
		_record(data, state)
		changed = true
	if changed:
		Profile.write(profile, data)
	return changed


## The run's Set count, from 0: the Quota now ending or just ended.
static func quota_number(state: RunState) -> int:
	return (state.year - 1) * SetConfig.SETS_PER_YEAR + state.set_index


static func _take_quota(data: ProfileData, state: RunState) -> bool:
	var quota: int = quota_number(state)
	if data.committed_run == state.identity.id and quota <= data.committed_quota:
		return false
	data.memory = VillageMemory.from_dict(state.memory.to_dict())
	# Corruption's events for the Quota are applied here once they exist (ADR 0025, step 5).
	data.committed_run = state.identity.id
	data.committed_quota = quota
	return true


static func _record(data: ProfileData, state: RunState) -> void:
	var outcome: String = Endings.outcome(state, RunLoop.DEFAULT_METERS)
	data.finished_runs += 1
	if not Endings.is_death(outcome):
		data.wins += 1
	var entry: HistoryEntry = HistoryEntry.new()
	entry.run_id = state.identity.id
	entry.generation = state.identity.generation
	entry.outcome = outcome
	entry.class_id = HistoryEntry.LANDLORD if YearClass.is_landlord(state) else HistoryEntry.PEASANT
	entry.year = state.year
	entry.household = state.identity.household
	entry.stake = state.identity.stake
	for found: RosterEntry in state.roster:
		if found.status == RosterEntry.Status.DEAD:
			entry.dead.append(Roster.name_key(RunLoop.DEFAULT_VILLAGE, found))
	data.add_history(entry)
