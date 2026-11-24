class_name ShopParams
extends Resource
## One counter's numbers (P4.10): the state store's or the black market's.

## Cadres offered per visit.
@export var slots: int = 3
## Directives offered per visit, beside the Cadres (ADR 0021).
@export var directive_slots: int = 0
## Cadres the player can hold at once, before any Reform. The player has one limit, so
## only the state store's is read, through RunReforms.
@export var cadre_slots: int = 5
## Campaigns offered per visit from this counter's pool, and how many the player can
## hold at once before any Reform, read like cadre_slots (ADR 0021).
@export var campaign_offers: int = 0
@export var campaign_slots: int = 2
## Reforms offered per visit (ADR 0021).
@export var reform_offers: int = 0
## Envelopes offered per visit, and the kinds this counter sells, drawn evenly from those
## with something to show (ADR 0021).
@export var envelope_offers: int = 0
@export var envelopes: Array[EnvelopeDef] = []
## Coupons for the first reroll, and how much each later one adds.
@export var reroll_base: int = 2
@export var reroll_step: int = 1
## Weight of each rarity, common first, when drawing stock.
@export var rarity_weights: Array[int] = [60, 30, 10]
## What an item costs here, as a percent of its listed cost, rounded up.
@export var price_percent: int = 100
## How many of one item this counter sells in a run. 0 means no limit.
@export var stock_per_item: int = 0
## What this counter pays for a held Cadre or Campaign sold back to it, as a percent of
## the item's price here now, rounded down, never under one coupon (ADR 0040).
@export var sell_percent: int = 50
