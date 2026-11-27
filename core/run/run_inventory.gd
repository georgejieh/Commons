class_name RunInventory
extends RefCounted
## What the player owns: Cadres in slot order, consumables, and the private plot.

## The held Cadre IDs, in slot order.
var cadres: Array[String] = []
## The held Campaign IDs.
var consumables: Array[String] = []
## The private plot's cards, each under a plot ID.
var plot: Array[CardInstance] = []


## Rebuilds the inventory from the run save.
static func from_dict(data: Dictionary) -> RunInventory:
	var inventory: RunInventory = RunInventory.new()
	inventory.cadres.assign(data["cadres"])
	inventory.consumables.assign(data["consumables"])
	for card_data: Dictionary in data["plot"]:
		inventory.plot.append(CardInstance.from_dict(card_data))
	return inventory


## The inventory as a map for the run save.
func to_dict() -> Dictionary:
	var plot_data: Array[Dictionary] = []
	for card: CardInstance in plot:
		plot_data.append(card.to_dict())
	return {"cadres": cadres.duplicate(), "consumables": consumables.duplicate(), "plot": plot_data}
