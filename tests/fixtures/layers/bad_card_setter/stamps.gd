extends RefCounted
## Fixture: changes a card without going through CardModifiers.


func stamp(card: CardInstance) -> void:
	card.set_owner_stamp(0)
