class_name NeedAudit
extends RefCounted
## Checks declared needs before a Commons split (P4.3). Each declaration is checked on
## the audit stream with one chance: base, plus an informer in the village, then the
## audit hook. A checked declaration above true need is a caught lie, and the split
## uses the true need in its place.


static func chance(state: RunState, params: AuditParams, stack: ModifierStack) -> float:
	var base: float = params.base_chance
	if informer_present(state, params):
		base += params.informer_chance
	var context: AuditContext = AuditContext.new(base)
	stack.run_audit(context)
	return clampf(context.chance, 0.0, 1.0)


## True while an informer family is seated or active on the roster.
static func informer_present(state: RunState, params: AuditParams) -> bool:
	for family_id: String in state.table:
		if params.informer_families.has(family_id):
			return true
	for entry: RosterEntry in state.roster:
		var active: bool = entry.status == RosterEntry.Status.ACTIVE
		if active and params.informer_families.has(entry.family_id):
			return true
	return false


## Checks each declaration in place: needs[i] falls to true_need when seats[i] is caught.
## Every seat rolls, so the stream moves the same whether or not anyone lied. Returns the
## caught seats.
static func run(
	seats: Array[int],
	needs: PackedInt64Array,
	true_need: int,
	audit_chance: float,
	stream: RandomStream,
	events: Array[RunEvent]
) -> Array[int]:
	var caught: Array[int] = []
	for index: int in seats.size():
		if stream.next_float() >= audit_chance:
			continue
		var lied: bool = needs[index] > true_need
		events.append(RunEvent.new(RunEvent.Type.AUDITED, seats[index], 1 if lied else 0))
		if lied:
			needs[index] = true_need
			caught.append(seats[index])
	return caught
