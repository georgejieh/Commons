class_name TournamentRow
extends RefCounted
## One line of tournament results: a configuration in one role at one seat.

var games: int = 0
var wins: int = 0
var illegal_actions: int = 0
var _usec: PackedInt64Array = PackedInt64Array()


func add(result: SelfPlayResult, seat: int, won: bool) -> void:
	games += 1
	wins += 1 if won else 0
	illegal_actions += result.illegal_by_seat[seat]
	for decision: int in result.decision_usec.size():
		if result.decision_seats[decision] == seat:
			_usec.append(result.decision_usec[decision])


func csv() -> String:
	var sorted: PackedInt64Array = _usec.duplicate()
	sorted.sort()
	var total: int = 0
	for usec: int in sorted:
		total += usec
	var count: int = sorted.size()
	var mean: float = float(total) / count if count > 0 else 0.0
	@warning_ignore("integer_division")
	var p99: int = sorted[count * 99 / 100] if count > 0 else 0
	return "%d,%d,%.4f,%.1f,%d,%d" % [games, wins, float(wins) / games, mean, p99, illegal_actions]
