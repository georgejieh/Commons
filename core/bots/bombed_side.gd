class_name BombedSide
extends RefCounted
## The tables a bot's own bomb is judged under (Controls): the seat's own and each
## opponent's as they stand once a bomb is down in the trick (ADR 0039), one table for
## each way of playing.

## The table the seat's own bomb is judged under once it is down in the trick.
var own: BotTable
## The tables the opponents play under once a bomb is down, one for each distinct way of
## playing, so opponents who play alike share one.
var rivals: Array[BotTable] = []


## The bombed side of a trick not yet bombed, for seat against its opponents, or null when
## a bomb changes no seat's rules or order.
static func of(table: BotTable, seat: int, opponents: Array[int]) -> BombedSide:
	if table.is_uniform() or table.bombed:
		return null
	var side: BombedSide = BombedSide.new()
	side.own = table.as_seat(seat, true)
	for other: int in opponents:
		var rival: BotTable = table.as_seat(other, true)
		var known: bool = side.rivals.any(
			func(seen: BotTable) -> bool:
				return seen.rules == rival.rules and seen.standing == rival.standing
		)
		if not known:
			side.rivals.append(rival)
	return side
