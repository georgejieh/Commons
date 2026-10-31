class_name BotRationale
extends RefCounted
## Why a bot acted, as a code. The words live in tools/, which never ships (ADR 0009).

enum Code {
	NONE,
	ONLY_MOVE,
	PASS_NOTHING_BEATS,
	LOWEST_BEATING_PLAY,
}
