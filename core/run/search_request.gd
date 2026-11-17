class_name SearchRequest
extends RefCounted
## What a searching villager's play is decided from while the loop stands still for it
## (P5.0): the seat, and copies of its view, its legal moves, its rules and its config.
## Nothing here is the live round's, so a search may read it on another thread while the
## table is drawn, and nothing the search does reaches the run.

var seat: int
var view: SeatView
var legal: Array[Pattern] = []
var table: BotTable
var config: BotConfig


## view is already the seat's own copy (RoundState.view_for); the rest is copied here,
## but for the RuleSet, which is never changed once built.
func _init(
	seat_index: int,
	seat_view: SeatView,
	moves: Array[Pattern],
	seat_table: BotTable,
	seat_config: BotConfig
) -> void:
	seat = seat_index
	view = seat_view
	for move: Pattern in moves:
		legal.append(move.copy())
	table = BotTable.new(seat_table.rules, seat_table.rank_map.duplicate())
	config = seat_config.copy()
