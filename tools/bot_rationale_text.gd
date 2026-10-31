class_name BotRationaleText
extends RefCounted
## Debug words for bot rationale codes. tools/ never ships, so release builds lack them.

const TEXT: Dictionary[BotRationale.Code, String] = {
	BotRationale.Code.NONE: "No reason recorded",
	BotRationale.Code.ONLY_MOVE: "Only one legal move",
	BotRationale.Code.PASS_NOTHING_BEATS: "Nothing beats passing",
	BotRationale.Code.LOWEST_BEATING_PLAY: "Lowest play that beats the table",
}
