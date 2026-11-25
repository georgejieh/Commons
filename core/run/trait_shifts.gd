class_name TraitShifts
extends RefCounted
## Family traits that change with a run meter (ADR 0043). While a meter stands in a shift's
## band or above it, a seated family plays with the shift's level of that trait in place
## of its own; once the meter is back below, the family's own level, as drift left it,
## returns. Only families with shifts are touched, so every other config, a mirrored one
## included, is left as it was.

const HONESTY: String = "honesty"


## Sets every seated family's traits as the meters stand now. Returns the seats whose
## honesty a shift holds now.
static func apply(
	state: RunState, configs: Array[BotConfig], book: VillageBook, meters: MeterTable
) -> Array[int]:
	var honesty_shifted: Array[int] = []
	if state.roster.is_empty():
		return honesty_shifted
	for seat: int in range(1, Seats.COUNT):
		var entry: RosterEntry = Roster.entry(state, state.table[seat])
		if entry == null:
			continue
		var family: FamilyDef = Roster.definition(book, entry)
		if family.shifts.is_empty():
			continue
		var traits: Personality = Roster.personality_for(book, entry, state.drift).duplicate()
		for shift: TraitShift in family.shifts:
			if holds(shift, state, meters):
				traits.set(shift.trait_name, shift.level)
				if shift.trait_name == HONESTY:
					honesty_shifted.append(seat)
		configs[seat].take_traits(traits)
	return honesty_shifted


## True while the shift's meter stands in its band or above.
static func holds(shift: TraitShift, state: RunState, meters: MeterTable) -> bool:
	return meters.bands(shift.meter).band(RunMeters.value(state, shift.meter)) >= shift.band


## Counts each claim above the fair half, among events from the index on, made from a seat
## whose honesty a shift held: what the player saw of it, for the dossier.
static func note_claims(
	state: RunState, seats: Array[int], events: Array[RunEvent], from: int, fair: int
) -> void:
	for index: int in range(from, events.size()):
		var event: RunEvent = events[index]
		if event.type == RunEvent.Type.NEED_DECLARED and seats.has(event.seat):
			if event.value > fair:
				state.observations.add(state.table[event.seat], Observations.Kind.SHIFTED_CLAIMS)


## A family's first honesty shift, whose line the dossier shows for its shifted claims, or
## null for a family with none.
static func seen_shift(book: VillageBook, state: RunState, family_id: String) -> TraitShift:
	var entry: RosterEntry = Roster.entry(state, family_id)
	var family: FamilyDef = (
		book.family(family_id) if entry == null else Roster.definition(book, entry)
	)
	if family == null:
		return null
	for shift: TraitShift in family.shifts:
		if shift.trait_name == HONESTY:
			return shift
	return null
