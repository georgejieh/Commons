class_name ConfiscationEffect
extends ModifierEffect
## Each round, held Cadres drawn at the round's start do nothing for the round: the run
## leaves them out of the stack, so their run state is kept as it was. With no Cadres it
## does nothing (ADR 0023).

const CADRES: String = "cadres"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([CADRES])


## The slots left out this round, lowest first, drawn on stream from held Cadres. No draw
## is made with none held.
func choose(held: int, stream: RandomStream) -> Array[int]:
	var slots: Array[int] = []
	for slot: int in held:
		slots.append(slot)
	var chosen: Array[int] = []
	while chosen.size() < parameters[CADRES] and not slots.is_empty():
		chosen.append(slots.pop_at(stream.next_int(0, slots.size() - 1)))
	chosen.sort()
	return chosen
