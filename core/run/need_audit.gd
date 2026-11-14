class_name NeedAudit
extends RefCounted
## Checks declared needs before a Commons split (P4.3). Each declaring seat rolls one die
## on the audit stream, and a face at or below the audit faces means its claim is
## checked. The faces are the base, plus one for an informer in the village, then the
## audit hook, and never every face. A checked declaration above true need is a caught
## lie, and the split uses the true need in its place.


## How many faces of the die mean an audit this split: from none to max_faces.
static func faces(state: RunState, params: AuditParams, stack: ModifierStack) -> int:
	var base: int = params.base_faces
	if informer_present(state, params):
		base += params.informer_faces
	var context: AuditContext = AuditContext.new(base)
	stack.run_audit(context)
	return clampi(context.faces, 0, mini(params.max_faces, params.die_sides))


## The chance, from 0 to 1, that each declaration is checked: faces over sides.
static func chance(state: RunState, params: AuditParams, stack: ModifierStack) -> float:
	return float(faces(state, params, stack)) / maxi(params.die_sides, 1)


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
## Every seat rolls once, so the stream moves the same whether or not anyone lied. Each
## roll is logged as AUDIT_ROLLED, value the face shown and amount the audit faces, and
## all of them come before any AUDITED. Returns the caught seats.
static func run(
	seats: Array[int],
	needs: PackedInt64Array,
	true_need: int,
	audit_faces: int,
	sides: int,
	stream: RandomStream,
	events: Array[RunEvent]
) -> Array[int]:
	var rolls: PackedInt64Array = PackedInt64Array()
	for seat: int in seats:
		var face: int = stream.next_int(1, sides)
		rolls.append(face)
		events.append(RunEvent.new(RunEvent.Type.AUDIT_ROLLED, seat, face, float(audit_faces)))
	var caught: Array[int] = []
	for index: int in seats.size():
		if rolls[index] > audit_faces:
			continue
		var lied: bool = needs[index] > true_need
		events.append(RunEvent.new(RunEvent.Type.AUDITED, seats[index], 1 if lied else 0))
		if lied:
			needs[index] = true_need
			caught.append(seats[index])
	return caught
