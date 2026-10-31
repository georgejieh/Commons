class_name BotRationaleText
extends RefCounted
## Debug words for bot rationale codes. tools/ never ships, so release builds lack them.

const TEXT: Dictionary[BotRationale.Code, String] = {
	BotRationale.Code.NONE: "No reason recorded",
	BotRationale.Code.PASS_NOTHING_BEATS: "Nothing beats passing",
	BotRationale.Code.BEST_SCORE: "Best hand left after playing",
	BotRationale.Code.GO_OUT: "Plays the whole hand",
	BotRationale.Code.FORCED_WIN: "Controls first, on the way to a forced win",
	BotRationale.Code.FEED_TEAMMATE: "Feeds a teammate close to going out",
	BotRationale.Code.WEAKEST_GROUP: "Leads the weakest group",
	BotRationale.Code.PASS_TEAMMATE: "Leaves the trick to a teammate",
	BotRationale.Code.BLOCK_OPPONENT: "Stops an opponent going out",
	BotRationale.Code.BLOCK_FOR_TEAMMATE: "Tops a weak teammate card to block the landlord",
	BotRationale.Code.BLOCK_LANDLORD: "Upstream seat blocks the landlord's single",
}
