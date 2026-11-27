class_name SlackPolicy
extends RefCounted
## A bot that isn't trying: it passes when following, and leads its weakest move.
## It still plays only legal moves.

## Keeps the effort roll apart from the cooperation roll.
const SALT: int = 0x5A1AC


## True when this decision is one the bot doesn't try on, from its own salted roll so it
## never moves with the cooperation roll.
static func slacks(view: SeatView, config: BotConfig) -> bool:
	return config.effort < 1.0 and BotPosition.roll_for(view, config, SALT) >= config.effort


## The play of a bot that isn't trying. legal must not be empty when it leads.
static func choose(view: SeatView, legal: Array[Pattern]) -> BotPlay:
	if view.public.current_play != null:
		return BotPlay.new(Pattern.pass_play(), BotRationale.Code.SLACKED)
	var weakest: Pattern = legal[0]
	for move: Pattern in legal:
		if move.key < weakest.key:
			weakest = move
	return BotPlay.new(weakest, BotRationale.Code.SLACKED)
