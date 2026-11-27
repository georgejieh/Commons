class_name OwnerStampEffect
extends ModifierEffect
## Cards stamped with the holder's mark score extra Grain, only when the holder
## plays them: dealt to anyone else a stamped card is plain. A private Cadre scores only
## the holder's plays (SeatScope, ADR 0039), so nothing here can open it to another seat.

## Parameter key: the Grain a card the holder stamped adds when scored.
const GRAIN: String = "grain"


## Needs the Grain.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([GRAIN])


## Adds the Grain to a scored card stamped with the holder's mark.
func card_scored(context: CardContext) -> void:
	if context.card.owner_stamp() == holder_seat:
		context.grain += parameters[GRAIN]
