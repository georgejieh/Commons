class_name TournamentTally
extends RefCounted
## Adds up games by configuration, role and seat, and writes them as CSV.

const COLUMNS: String = "mean_usec,p99_usec,illegal_actions"
const HEADER: String = "mode,config,role,seat,games,wins,win_rate," + COLUMNS
const ROLES: Array[String] = ["landlord", "peasant"]

var illegal_actions: int = 0
## Rows keyed "mode,config,role,seat", in first-seen order.
var _rows: Dictionary[String, TournamentRow] = {}


func add(mode: String, names: Array[String], result: SelfPlayResult) -> void:
	illegal_actions += result.illegal_actions
	for seat: int in Seats.COUNT:
		var is_landlord: bool = seat == result.landlord
		var role: String = ROLES[0] if is_landlord else ROLES[1]
		var key: String = "%s,%s,%s,%d" % [mode, names[seat], role, seat]
		if not _rows.has(key):
			_rows[key] = TournamentRow.new()
		_rows[key].add(result, seat, result.landlord_won() == is_landlord)


## A config's wins as a share of the sides it played in one mode. Peasants win as a pair,
## so each game counts once per side.
func win_rate(mode: String, config: String) -> float:
	var sides: float = 0.0
	var wins: float = 0.0
	for key: String in _rows:
		var parts: PackedStringArray = key.split(",")
		if parts[0] != mode or parts[1] != config:
			continue
		var share: float = 1.0 if parts[2] == ROLES[0] else 0.5
		sides += _rows[key].games * share
		wins += _rows[key].wins * share
	return wins / sides if sides > 0 else 0.0


func csv() -> String:
	var lines: PackedStringArray = PackedStringArray([HEADER])
	for key: String in _rows:
		lines.append("%s,%s" % [key, _rows[key].csv()])
	return "\n".join(lines) + "\n"
