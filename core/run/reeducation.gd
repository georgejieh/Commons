class_name Reeducation
extends RefCounted
## What reeducation changes about the player (ADR 0019): one held Cadre is exchanged,
## in its slot, for one they do not hold. Nothing changes when they hold none, or when
## the pool has nothing left to give.


## Returns [old ID, new ID], or an empty array when nothing changed.
static func change_cadre(
	inventory: RunInventory, pool: Array[ModifierDef], stream: RandomStream
) -> PackedStringArray:
	if inventory.cadres.is_empty():
		return PackedStringArray()
	var open: Array[String] = []
	for definition: ModifierDef in pool:
		if not inventory.cadres.has(definition.id):
			open.append(definition.id)
	if open.is_empty():
		return PackedStringArray()
	var slot: int = stream.next_int(0, inventory.cadres.size() - 1)
	var replacement: String = open[stream.next_int(0, open.size() - 1)]
	var old: String = inventory.cadres[slot]
	inventory.cadres[slot] = replacement
	return PackedStringArray([old, replacement])
