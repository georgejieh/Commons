class_name ReformEffect
extends RefCounted
## Base for a Reform's behaviour (ADR 0021). A Reform changes one thing the run reads for
## the rest of the run: a limit, what a Quota pays or costs, an envelope's choices, or how
## the deck is dealt. Each effect answers its own question from its parameters, leaves
## every other at nothing, and changes nothing itself.

var parameters: Dictionary[String, int] = {}


## Names every parameter the definition must supply.
func required_parameters() -> PackedStringArray:
	return PackedStringArray()


## More Cadres the player can hold.
func extra_cadres() -> int:
	return 0


## More Campaigns the player can hold.
func extra_campaigns() -> int:
	return 0


## More items in every envelope to choose from (P4.11g).
func extra_envelope_choices() -> int:
	return 0


## More coupons for every Quota met.
func quota_coupons() -> int:
	return 0


## Less Famine for every Quota missed.
func famine_relief() -> int:
	return 0


## True when the deck is gathered and cut between a Quota's rounds, not shuffled.
func gathers_deck() -> bool:
	return false


## Ranks drawn wild with every deal, for the player's seat alone (ADR 0029, ADR 0039).
func wild_ranks_per_round() -> int:
	return 0


## The hooks of a rule this Reform gives the player's seat, or none. The run adds the rule
## to the modifier stack each round, after the Cadres, held by the player (ADR 0029,
## ADR 0039).
func rule_hooks() -> Array[String]:
	return []


## The rule's effect, with this Reform's parameters, or null with no rule.
func table_rule() -> ModifierEffect:
	return null
