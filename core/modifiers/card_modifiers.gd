class_name CardModifiers
extends RefCounted
## The modifier service: the only core code allowed to change a card's enhancement, seal
## or stamp. The layer check enforces this.


static func enhance(card: CardInstance, enhancement_id: String) -> void:
	card.set_enhancement(enhancement_id)


static func seal(card: CardInstance, seal_id: String) -> void:
	card.set_seal(seal_id)


static func stamp(card: CardInstance, player: int) -> void:
	card.set_owner_stamp(player)
