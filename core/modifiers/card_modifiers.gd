class_name CardModifiers
extends RefCounted
## The modifier service: the only core code allowed to change a card's enhancement, seal
## or stamp. The layer check enforces this.


## Gives the card an enhancement by ID, in place of any other it carries.
static func enhance(card: CardInstance, enhancement_id: String) -> void:
	card.set_enhancement(enhancement_id)


## Gives the card a seal by ID.
static func seal(card: CardInstance, seal_id: String) -> void:
	card.set_seal(seal_id)


## Stamps the card as the player's own, by seat.
static func stamp(card: CardInstance, player: int) -> void:
	card.set_owner_stamp(player)
