class_name Hooks
extends RefCounted
## The fixed hook list. Each name is also the ModifierEffect method it calls.

const BUILD_RULESET: String = "build_ruleset"
const BUILD_RANK_MAP: String = "build_rank_map"
const ON_DEAL: String = "on_deal"
const ROUND_START: String = "round_start"
const PLAY_SCORED: String = "play_scored"
const CARD_SCORED: String = "card_scored"
const ROUND_END: String = "round_end"
const SET_END: String = "set_end"
const SHOP_OPEN: String = "shop_open"
const METER_CHANGE: String = "meter_change"
const AUDIT: String = "audit"
## After each real play or pass, never a preview (ADR 0021).
const TURN_TAKEN: String = "turn_taken"
## After a round's Commons split and its audit (ADR 0032).
const NEED_SETTLED: String = "need_settled"

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
