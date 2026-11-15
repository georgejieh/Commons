class_name CardBackPool
extends Resource
## Every card back design, in the order Settings shows them. The first is the one a
## player has before choosing, and the one a choice falls back to.

@export var backs: Array[CardBackDef] = []


## The design with this ID, or null.
func back(back_id: String) -> CardBackDef:
	for definition: CardBackDef in backs:
		if definition.id == back_id:
			return definition
	return null
