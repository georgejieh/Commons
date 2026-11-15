class_name VillageFates
extends RefCounted
## The two roster rules that end a family's part in a run (ADR 0025). At a Quota's end in
## high Famine one seated family starves: it is dead for the rest of the run. A risen
## villager whose boss Quota the player meets is deposed: out of the village until the
## next Year starts. A boss never starves, and a run with no roster has no families to
## lose. Nothing here draws a random number.


## At a Quota's end with Famine in its high band, while fewer than per_year families have
## starved this Year, the seated family fed least at the Commons split this Quota dies,
## the later seat on a tie. Returns its family ID, or "".
static func starve(state: RunState, famine: MeterBands, per_year: int, set_log: SetLog) -> String:
	if state.roster.is_empty() or state.summaries.is_empty():
		return ""
	if famine.band(state.famine) != MeterBands.Band.HIGH or state.year_starved >= per_year:
		return ""
	var summary: SetSummary = state.summaries[-1]
	var chosen: int = Seats.NONE
	var fewest: int = 0
	for seat: int in range(1, mini(state.table.size(), Seats.COUNT)):
		var family_id: String = state.table[seat]
		var entry: RosterEntry = Roster.entry(state, family_id)
		if entry == null or entry.status != RosterEntry.Status.ACTIVE:
			continue
		if family_id == state.boss_family:
			continue
		var fed: int = summary.count(family_id, SetSummary.Kind.FED)
		if chosen == Seats.NONE or fed <= fewest:
			chosen = seat
			fewest = fed
	if chosen == Seats.NONE:
		return ""
	var dead: RosterEntry = Roster.entry(state, state.table[chosen])
	dead.status = RosterEntry.Status.DEAD
	dead.return_timer = 0
	state.year_starved += 1
	set_log.add(RunEvent.new(RunEvent.Type.STARVED, chosen, fewest, 0.0, dead.family_id))
	return dead.family_id


## A met Quota against a risen villager deposes it. It already ran its boss Set, so the
## boss pool never offers it again this run. Returns its family ID, or "".
static func depose(state: RunState, risen_boss_id: String, set_log: SetLog) -> String:
	if state.boss_id != risen_boss_id or state.boss_family.is_empty():
		return ""
	var entry: RosterEntry = Roster.entry(state, state.boss_family)
	if entry == null or entry.status != RosterEntry.Status.ACTIVE:
		return ""
	entry.status = RosterEntry.Status.DEPOSED
	var seat: int = state.table.find(entry.family_id)
	set_log.add(RunEvent.new(RunEvent.Type.DEPOSED, seat, 0, 0.0, entry.family_id))
	return entry.family_id


## A new Year brings every deposed family back into the village, and may starve again.
static func new_year(state: RunState, set_log: SetLog) -> void:
	state.year_starved = 0
	for entry: RosterEntry in state.roster:
		if entry.status != RosterEntry.Status.DEPOSED:
			continue
		entry.status = RosterEntry.Status.ACTIVE
		set_log.add(
			RunEvent.new(
				RunEvent.Type.ROSTER_CHANGED, Seats.NONE, entry.status, 0.0, entry.family_id
			)
		)


## True when the family is gone from the village: dead, or deposed until the next Year.
static func is_gone(state: RunState, family_id: String) -> bool:
	var entry: RosterEntry = Roster.entry(state, family_id)
	if entry == null:
		return false
	return entry.status == RosterEntry.Status.DEAD or entry.status == RosterEntry.Status.DEPOSED
