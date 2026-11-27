class_name UnplannedEconomyEffect
extends ReformEffect
## Unplanned Economy: the deck is gathered in the order the last round left it and cut,
## not shuffled, between the rounds of a Quota (DeckOrder).


func gathers_deck() -> bool:
	return true
