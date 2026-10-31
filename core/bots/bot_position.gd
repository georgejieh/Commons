class_name BotPosition
extends RefCounted
## What one decision knows about the table, worked out once from the seat's own view.

const NO_CARDS: int = 99

var view: SeatView
var table: BotTable
var config: BotConfig
var scorer: CandidateScorer
var seat: int
var teammate: int = Seats.NONE
## Fewest cards any opponent holds.
var opponent_cards: int = NO_CARDS
var teammate_cards: int = NO_CARDS
var unseen: PackedByteArray
var groups: Array[Pattern]
var controls: Controls


func _init(
	seat_view: SeatView, seat_table: BotTable, bot_config: BotConfig, scorer_in: CandidateScorer
) -> void:
	view = seat_view
	table = seat_table
	config = bot_config
	scorer = scorer_in
	seat = view.seat
	_read_seats()
	unseen = UnseenCards.from_view(view)
	groups = scorer.decompose_own_hand().groups
	controls = Controls.new(groups, unseen, _largest_opposing_hand(), table)


func hand_size() -> int:
	return view.public.remaining[seat]


func is_landlord() -> bool:
	return seat == view.public.landlord


func is_opponent(other: int) -> bool:
	return other != seat and other != teammate


## The seat whose play is on the table, or Seats.NONE when leading.
func trick_owner() -> int:
	if view.public.current_play == null:
		return Seats.NONE
	for index: int in range(view.public.history.size() - 1, -1, -1):
		var entry: PublicPlay = view.public.history[index]
		if entry.pattern.type != Pattern.Type.PASS:
			return entry.seat
	return Seats.NONE


## The seat that plays just before the landlord.
func is_upstream() -> bool:
	return Seats.next(seat) == view.public.landlord


func forced_win() -> bool:
	return controls.effective_hands <= 1


## The move that empties the hand, or null.
func going_out(legal: Array[Pattern]) -> Pattern:
	for move: Pattern in legal:
		if move.card_count == hand_size():
			return move
	return null


func rank_of(rank: int) -> int:
	return table.rank_map[rank]


func _read_seats() -> void:
	var landlord: int = view.public.landlord
	if seat != landlord:
		for other: int in Seats.COUNT:
			if other != seat and other != landlord:
				teammate = other
	for other: int in Seats.COUNT:
		if other == teammate and other != seat:
			teammate_cards = view.public.remaining[other]
		elif other != seat:
			opponent_cards = mini(opponent_cards, view.public.remaining[other])


func _largest_opposing_hand() -> int:
	var largest: int = 0
	for other: int in Seats.COUNT:
		if is_opponent(other):
			largest = maxi(largest, view.public.remaining[other])
	return largest
