class_name BotRationaleText
extends RefCounted
## Debug words for bot rationale codes. tools/ never ships, so release builds lack them.

const TEXT: Dictionary[BotRationale.Code, String] = {
	BotRationale.Code.NONE: "No reason recorded",
	BotRationale.Code.PASS_NOTHING_BEATS: "Nothing beats passing",
	BotRationale.Code.BEST_SCORE: "Best hand left after playing",
}
