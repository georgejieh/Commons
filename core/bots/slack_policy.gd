class_name SlackPolicy
extends RefCounted
## A bot that isn't trying (P4.4): it passes when following, and leads its weakest move.
## It still plays only legal moves.


static func choose(position: BotPosition, legal: Array[Pattern]) -> BotPlay:
	if position.view.public.current_play != null:
		return BotPlay.new(Pattern.pass_play(), BotRationale.Code.SLACKED)
	var weakest: Pattern = legal[0]
	for move: Pattern in legal:
		if move.key < weakest.key:
			weakest = move
	return BotPlay.new(weakest, BotRationale.Code.SLACKED)
