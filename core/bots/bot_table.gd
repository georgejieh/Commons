class_name BotTable
extends RefCounted
## The rules a bot plays under, from the same SeatRules the round reads. rules and
## rank_map are the deciding seat's own; standing is its standings (Standing), which a
## play's key reads. A table built from SeatRules also knows every other seat's rules and
## orders, before and after a bomb in the trick, so a bot reads another seat's replies as
## that seat plays them (ADR 0039). A table built from one seat's rules alone plays every
## seat so. Nothing changes a table once built, so search threads may share one.

## The deciding seat's rules.
var rules: RuleSet
## The deciding seat's order: the place of each printed rank, from low to high.
var rank_map: PackedByteArray
## The deciding seat's standings, which the key of a play is read in.
var standing: PackedByteArray
## The seat these are, or Seats.NONE when every seat plays the same.
var seat: int = Seats.NONE
## True when the trick on the table has had a bomb.
var bombed: bool = false

## Every seat's rules, order and standings, before a bomb at index seat and after one at
## COUNT + seat, shared by every table made from them. Empty when every seat plays as
## this one.
var _seat_rules: Array[RuleSet] = []
var _maps: Array[PackedByteArray] = []
var _standings: Array[PackedByteArray] = []


func _init(seat_rules: RuleSet, seat_map: PackedByteArray) -> void:
	rules = seat_rules
	rank_map = seat_map
	standing = Standing.of(seat_map)


## The seat's table in the round as it stands, knowing every seat. While every seat
## plays under the same rules and order on both sides of a bomb, as with no seat-only
## modifier in force, it is a plain table.
static func of_seat(table: SeatRules, at: int) -> BotTable:
	var known: BotTable = BotTable.new(table.rules_for(at), table.map_for(at))
	known.standing = table.standing_for(at)
	var alike: bool = true
	for after_bomb: bool in [false, true]:
		for other: int in Seats.COUNT:
			known._seat_rules.append(table.rules_for(other))
			known._maps.append(table.map_in(other, after_bomb))
			known._standings.append(table.standing_in(other, after_bomb))
			alike = (
				alike
				and known._seat_rules.back() == known.rules
				and known._standings.back() == known.standing
			)
	if alike:
		known._seat_rules.clear()
		known._maps.clear()
		known._standings.clear()
		return known
	return known.as_seat(at, table.trick_bombed())


## A copy sharing nothing a thread could change (SearchRequest).
func copied() -> BotTable:
	var result: BotTable = BotTable.new(rules, rank_map.duplicate())
	result.standing = standing.duplicate()
	result.seat = seat
	result.bombed = bombed
	result._seat_rules = _seat_rules.duplicate()
	for index: int in _maps.size():
		result._maps.append(_maps[index].duplicate())
		result._standings.append(_standings[index].duplicate())
	return result


## True when every seat plays under this seat's rules and order, on both sides of a bomb.
func is_uniform() -> bool:
	return _maps.is_empty()


## Another seat's own order in the trick as it stands.
func map_of(other: int) -> PackedByteArray:
	return rank_map if is_uniform() else _maps[_index(other, bombed)]


## The table that seat plays under, before a bomb in the trick or after one, as a bot
## deciding for that seat would hold it. A new table each call, so a caller that asks
## often keeps the ones it uses.
func as_seat(other: int, after_bomb: bool) -> BotTable:
	if is_uniform():
		return self
	var index: int = _index(other, after_bomb)
	var result: BotTable = BotTable.new(_seat_rules[index], _maps[index])
	result.standing = _standings[index]
	result.seat = other
	result.bombed = after_bomb
	result._seat_rules = _seat_rules
	result._maps = _maps
	result._standings = _standings
	return result


static func _index(at: int, after_bomb: bool) -> int:
	return (Seats.COUNT if after_bomb else 0) + at
