class_name Bosses
extends RefCounted
## Chooses who runs each boss Set (P4.7). The run's last boss is always the New Landlord.
## Before that, odd Years bring an official and even Years a risen villager, falling back
## to an official when no risen villager is left. Officials do not repeat until all have
## run. Draws are on the events stream.

const NO_FAMILY: String = ""


## The boss for the state's Year, recording what it used.
static func choose(
	state: RunState, pool: BossPool, years: int, stream: RandomStream
) -> ModifierDef:
	if state.year >= years:
		return pool.new_landlord
	var fresh: Array[String] = []
	for family_id: String in state.risen:
		if not state.risen_used.has(family_id):
			fresh.append(family_id)
	if state.year % 2 == 0 and not fresh.is_empty():
		var family_id: String = fresh[stream.next_int(0, fresh.size() - 1)]
		state.risen_used.append(family_id)
		state.boss_family = family_id
		return pool.risen
	return _official(state, pool, stream)


## The family that held every round's landlord seat in a Set, or NO_FAMILY. A round's
## holder is the seat named by its SEAT_KEPT or SEAT_LOST event.
static func full_set_holder(events: Array[RunEvent], table: Array[String], player: int) -> String:
	var holder: int = Seats.NONE
	for event: RunEvent in events:
		if event.type != RunEvent.Type.SEAT_KEPT and event.type != RunEvent.Type.SEAT_LOST:
			continue
		if holder != Seats.NONE and event.seat != holder:
			return NO_FAMILY
		holder = event.seat
	if holder == Seats.NONE or holder == player:
		return NO_FAMILY
	return table[holder]


## Destroys up to count held Cadres, drawn at random. Returns their IDs.
static func purge(inventory: RunInventory, count: int, stream: RandomStream) -> Array[String]:
	var destroyed: Array[String] = []
	for index: int in mini(count, inventory.cadres.size()):
		var slot: int = stream.next_int(0, inventory.cadres.size() - 1)
		destroyed.append(inventory.cadres[slot])
		inventory.cadres.remove_at(slot)
	return destroyed


static func _official(state: RunState, pool: BossPool, stream: RandomStream) -> ModifierDef:
	var open: Array[ModifierDef] = []
	for official: ModifierDef in pool.officials:
		if not state.officials_used.has(official.id):
			open.append(official)
	if open.is_empty():
		state.officials_used.clear()
		open = pool.officials.duplicate()
	var chosen: ModifierDef = open[stream.next_int(0, open.size() - 1)]
	state.officials_used.append(chosen.id)
	return chosen
