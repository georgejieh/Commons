class_name UnplannedEconomyEffect
extends ReformEffect
## Unplanned Economy: the deck is gathered in the order the last round left it and cut,
## not shuffled, between the rounds of a Quota (DeckOrder).


## True: the deck is gathered and cut, not shuffled, between a Quota's rounds.
func gathers_deck() -> bool:
	return true
