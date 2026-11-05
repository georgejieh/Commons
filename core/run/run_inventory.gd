class_name RunInventory
extends RefCounted
## What the player owns: Cadres in slot order, consumables, and the private plot.

var cadres: Array[String] = []
var consumables: Array[String] = []
var plot: Array[CardInstance] = []


static func from_dict(data: Dictionary) -> RunInventory:
	var inventory: RunInventory = RunInventory.new()
	inventory.cadres.assign(data["cadres"])
	inventory.consumables.assign(data["consumables"])
	for card_data: Dictionary in data["plot"]:
		inventory.plot.append(CardInstance.from_dict(card_data))
	return inventory


func to_dict() -> Dictionary:
	var plot_data: Array[Dictionary] = []
	for card: CardInstance in plot:
		plot_data.append(card.to_dict())
	return {"cadres": cadres.duplicate(), "consumables": consumables.duplicate(), "plot": plot_data}
