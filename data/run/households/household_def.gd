class_name HouseholdDef
extends Resource
## One household a full run can start as (ADR 0025): the family background picked at run
## setup, which sets what the run begins with and nothing after. A stronger start is paid
## for in Resentment, Denunciation or Famine. Applied by RunOpening before the first
## checkpoint.

@export var id: String
## Finished runs needed before it can be picked.
@export var unlock_tier: int = 0
## The string key of its name.
@export var name_key: String
## Its rules line, filled from text_values().
@export var text_key: String
## Coupons on top of the run's starting coupons.
@export var coupons: int = 0
## Plain cards put into the private plot, each a rank from plot_low_rank to plot_high_rank
## and a suit drawn evenly.
@export var plot_cards: int = 0
## The lowest rank of those cards, as a Ranks value: 7 is 10.
@export var plot_low_rank: int = 7
## The highest rank of those cards, as a Ranks value: 10 is K.
@export var plot_high_rank: int = 10
## A Cadre held from the start, or empty for none.
@export var cadre_id: String = ""
## Resentment the village holds from the first deal.
@export var resentment: int = 0
## Denunciation the village holds from the first deal.
@export var denunciation: int = 0
## Famine the village starts at (ADR 0032).
@export var famine: int = 0


## The numbers its rules line prints: coupons as the full starting amount.
func text_values(base_coupons: int) -> Dictionary[String, Variant]:
	return {
		"coupons": base_coupons + coupons,
		"cards": plot_cards,
		"resentment": resentment,
		"denunciation": denunciation,
		"famine": famine,
	}
