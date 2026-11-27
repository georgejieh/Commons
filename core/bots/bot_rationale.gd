class_name BotRationale
extends RefCounted
## Why a bot acted, as a code. The words live in tools/, which never ships (ADR 0009).

## Which rule picked a play. SEARCHED is an Expert's search and SLACKED a bot not trying;
## NONE is for a play with no recorded rule.
enum Code {
	NONE,
	PASS_NOTHING_BEATS,
	BEST_SCORE,
	GO_OUT,
	FORCED_WIN,
	FEED_TEAMMATE,
	WEAKEST_GROUP,
	PASS_TEAMMATE,
	BLOCK_OPPONENT,
	BLOCK_FOR_TEAMMATE,
	BLOCK_LANDLORD,
	GREEDY,
	SEARCHED,
	SLACKED,
}
