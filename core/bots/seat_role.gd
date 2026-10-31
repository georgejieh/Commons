class_name SeatRole
extends RefCounted
## What each peasant seat does. The upstream peasant plays just before the landlord: it
## blocks the landlord's singles, then feeds its teammate. The downstream peasant runs,
## shedding cheaply and saving controls.


## The upstream seat's answer to the landlord's single: its lowest card from the block
## rank up, or null when it holds none or this is not that position.
static func block_landlord_single(position: BotPosition, legal: Array[Pattern]) -> Pattern:
	var play: Pattern = position.view.public.current_play
	var from_landlord: bool = position.trick_owner() == position.view.public.landlord
	if not position.is_upstream() or not from_landlord or play.type != Pattern.Type.SINGLE:
		return null
	var low_rank: int = position.config.weights.block_low_rank
	var lowest: Pattern = null
	for move: Pattern in legal:
		var fits: bool = move.type == Pattern.Type.SINGLE and move.main_rank <= Ranks.TWO
		if fits and position.rank_of(move.main_rank) >= low_rank:
			if lowest == null or move.key < lowest.key:
				lowest = move
	return lowest


## The downstream seat saves its controls, so it answers with none of them unless a gate
## is open. Other seats keep every move.
static func saved_for_later(position: BotPosition, moves: Array[Pattern]) -> Array[Pattern]:
	if position.is_landlord() or position.is_upstream() or position.forced_win():
		return moves
	var kept: Array[Pattern] = []
	for move: Pattern in moves:
		if move.type != Pattern.Type.SINGLE or move.main_rank < Ranks.ACE:
			kept.append(move)
	return kept


## The upstream seat's lead: its lowest loose single or pair, so its teammate can take over.
static func feed_lead(position: BotPosition, moves: Array[Pattern]) -> Pattern:
	if not position.is_upstream() or position.is_landlord():
		return null
	var lowest: Pattern = null
	for index: int in position.groups.size():
		var group: Pattern = position.groups[index]
		var loose: bool = group.type == Pattern.Type.SINGLE or group.type == Pattern.Type.PAIR
		if not loose or position.controls.flags[index]:
			continue
		for move: Pattern in moves:
			if move.equals(group) and (lowest == null or move.key < lowest.key):
				lowest = move
	return lowest
