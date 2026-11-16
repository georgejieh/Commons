class_name TutorialRound
extends Resource
## One authored round of the arrival (ADR 0026): the deck in deal order, what each
## villager does, and the faces the audit dice show.

## The 54 deck card IDs in deal order: seat 0's 17, seat 1's 17, seat 2's 17, the kitty.
@export var deal: PackedInt32Array = PackedInt32Array()
## One per seat. The player's entry is empty: the player's moves are the steps.
@export var seats: Array[TutorialSeat] = []
## The face each declaring seat's audit die shows, in seat order.
@export var audit_faces: PackedInt32Array = PackedInt32Array()
