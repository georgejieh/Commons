class_name TutorialSeat
extends Resource
## What one villager does in one authored round of the arrival (ADR 0026), in the order
## the round asks: each bid, each play, and each need it declares.

## One entry per time the seat is asked to bid: 1 calls or grabs, 0 passes.
@export var bids: PackedInt32Array = PackedInt32Array()
## One entry per turn, the card IDs played; an empty entry is a pass.
@export var plays: Array[PackedInt32Array] = []
## One entry per Commons split the seat declares at.
@export var needs: PackedInt32Array = PackedInt32Array()
