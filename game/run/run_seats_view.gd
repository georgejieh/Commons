class_name RunSeatsView
extends RefCounted
## Who sits at the table and who they are: the families in the villagers' seats, their
## names, voices and what the player has seen of them, the player's own name, and how
## the run ended. RunController builds it over each run it attaches, as
## controller.seats.

var _loop: RunLoop


func _init(loop: RunLoop) -> void:
	_loop = loop


## True when the run seats the village's roster, as a full run does. The demo seats its
## two fixed villagers and ends on its own closing screen instead of an ending.
func has_village() -> bool:
	return not _loop.state.roster.is_empty()


## True for a full run: the one-time tooltips show only there (ADR 0026).
func is_full_run() -> bool:
	return _loop.state.identity.is_full()


## The family in a villager's seat, or null when the run seats no roster.
func seated_family(seat: int) -> FamilyDef:
	var entry: RosterEntry = _seated(seat)
	return null if entry == null else Roster.definition(RunDefaults.VILLAGE, entry)


## The surname key shown for a villager's seat, or "" when the run seats no roster.
func seated_name_key(seat: int) -> String:
	var entry: RosterEntry = _seated(seat)
	return "" if entry == null else Roster.name_key(RunDefaults.VILLAGE, entry)


## The full name of the family in a villager's seat, "Jianguo Wang", or its surname
## alone in a run that names nobody, as the demo's villagers are (ADR 0028).
func seated_full_name(seat: int) -> String:
	return RunPeople.seat_full_name(_loop.state, seat)


## The seated family's voice as this generation has it, or null with no roster.
func seated_voice(seat: int) -> VoiceProfile:
	return RunPeople.seat_voice(_loop.state, seat)


## The player's full name in this run, or their surname alone in one that names nobody.
func player_name() -> String:
	return RunPeople.player_full_name(_loop.state)


## The surname key of a family in the run's roster, or "" for one it does not hold.
func family_name_key(family_id: String) -> String:
	var entry: RosterEntry = Roster.entry(_loop.state, family_id)
	return "" if entry == null else Roster.name_key(RunDefaults.VILLAGE, entry)


## True when the family in a villager's seat is gone from the village: dead, or deposed
## until the next Year. Its panel is not shown again (ADR 0025).
func seat_gone(seat: int) -> bool:
	var state: RunState = _loop.state
	if seat <= 0 or seat >= state.table.size():
		return false
	return VillageFates.is_gone(state, state.table[seat])


## True when a family in a villager's seat remembers anything of the player.
func remembers_seated() -> bool:
	var state: RunState = _loop.state
	for seat: int in range(1, state.table.size()):
		var family: String = state.table[seat]
		if not state.memory.counts.has(family):
			continue
		for count: float in state.memory.counts[family]:
			if count != 0.0:
				return true
	return false


## The dossier's line for the claims a seated family made while a trait shift held (ADR
## 0043), or "" until the player has seen one.
func shift_line(seat: int) -> String:
	var state: RunState = _loop.state
	if seat <= 0 or seat >= state.table.size():
		return ""
	var family_id: String = state.table[seat]
	var count: int = state.observations.count(family_id, Observations.Kind.SHIFTED_CLAIMS)
	var shift: TraitShift = TraitShifts.seen_shift(RunDefaults.VILLAGE, state, family_id)
	if count == 0 or shift == null:
		return ""
	var at: int = RunDefaults.METERS.bands(shift.meter).least(shift.band)
	return tr(shift.seen_key).format({"count": count, "at": at})


## How the run ended, for the ending screen (ADR 0024), worked out from its state alone.
func ending() -> EndingView:
	return EndingView.of(_loop.state, RunPeople.player_surname(_loop.state))


## A copy of the roster entry in a villager's seat, or null when the run seats no roster.
func _seated(seat: int) -> RosterEntry:
	var state: RunState = _loop.state
	if state.roster.is_empty() or seat <= 0 or seat >= state.table.size():
		return null
	var entry: RosterEntry = Roster.entry(state, state.table[seat])
	return null if entry == null else RosterEntry.from_dict(entry.to_dict())
