class_name Hooks
extends RefCounted
## The fixed hook list. Each name is also the ModifierEffect method it calls.

const BUILD_RULESET: String = "build_ruleset"
const BUILD_RANK_MAP: String = "build_rank_map"
const ON_DEAL: String = "on_deal"
const ROUND_START: String = "round_start"
const PLAY_SCORED: String = "play_scored"
const CARD_SCORED: String = "card_scored"
const TRICK_WON: String = "trick_won"
const ROUND_END: String = "round_end"
const SET_END: String = "set_end"
const SHOP_OPEN: String = "shop_open"
const METER_CHANGE: String = "meter_change"

const ALL: PackedStringArray = [
	BUILD_RULESET,
	BUILD_RANK_MAP,
	ON_DEAL,
	ROUND_START,
	PLAY_SCORED,
	CARD_SCORED,
	TRICK_WON,
	ROUND_END,
	SET_END,
	SHOP_OPEN,
	METER_CHANGE,
]
