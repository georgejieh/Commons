class_name Hooks
extends RefCounted
## The fixed hook list. Each name is also the ModifierEffect method it calls.

## Builds a seat's RuleSet, from the base rules, when the table's cache is rebuilt.
const BUILD_RULESET: String = "build_ruleset"
## Builds a seat's effective-rank map, when the table's cache is rebuilt.
const BUILD_RANK_MAP: String = "build_rank_map"
## After a round is dealt, with the deal, before anyone plays.
const ON_DEAL: String = "on_deal"
## As a round starts, after the kitty is taken and before the first play.
const ROUND_START: String = "round_start"
## When a play is scored, in a preview too, so it only reads a CadreMemo.
const PLAY_SCORED: String = "play_scored"
## When each card of a play is scored, to change that card's Grain.
const CARD_SCORED: String = "card_scored"
## When a round has ended, before its totals fill the Commons.
const ROUND_END: String = "round_end"
## When a Set has ended, with whether its Quota was met.
const SET_END: String = "set_end"
## When a shop opens, to change what this visit offers.
const SHOP_OPEN: String = "shop_open"
## When a meter is about to change, to edit the change.
const METER_CHANGE: String = "meter_change"
## Before declared needs are checked, to change how many faces of the audit die mean a check.
const AUDIT: String = "audit"
## After each real play or pass, never a preview (ADR 0021).
const TURN_TAKEN: String = "turn_taken"
## After a round's Commons split and its audit (ADR 0032).
const NEED_SETTLED: String = "need_settled"

## Every hook name: the stack lists its entries by each, and a definition may name only these.
const ALL: PackedStringArray = [
	BUILD_RULESET,
	BUILD_RANK_MAP,
	ON_DEAL,
	ROUND_START,
	PLAY_SCORED,
	CARD_SCORED,
	ROUND_END,
	SET_END,
	SHOP_OPEN,
	METER_CHANGE,
	AUDIT,
	TURN_TAKEN,
	NEED_SETTLED,
]
