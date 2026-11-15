class_name BotPosition
extends RefCounted
## What one decision knows about the table, worked out once from the seat's own view.

const NO_CARDS: int = 99
## Keeps the effort roll apart from the cooperation roll.
const SLACK_SALT: int = 0x5A1AC

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
## The unseen cards an opponent could hold: all of them, unless a hand shown to the table
## (Glass Walls) tells the bot which of them a teammate holds or which seat holds what.
var threats: PackedByteArray
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
	threats = _threats()
	groups = scorer.decompose_own_hand().groups
	var counts_cards: bool = config.reads_the_table()
	controls = Controls.new(groups, threats, _largest_opposing_hand(), table, counts_cards)


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


## Passes made since the play on the table.
func passes_on_table() -> int:
	var passes: int = 0
	for index: int in range(view.public.history.size() - 1, -1, -1):
		if view.public.history[index].pattern.type != Pattern.Type.PASS:
			break
		passes += 1
	return passes


## The seat that plays just before the landlord.
func is_upstream() -> bool:
	return Seats.next(seat) == view.public.landlord


## Roles and endgame blocking belong to the tiers that read the table.
func plays_a_role() -> bool:
	return config.reads_the_table() and not is_landlord()


func forced_win() -> bool:
	return controls.effective_hands <= 1


## The move that empties the hand, or null.
func going_out(legal: Array[Pattern]) -> Pattern:
	for move: Pattern in legal:
		if move.card_count == hand_size():
			return move
	return null


## Reads other groups the way this hand's own were read.
## The landlord, alone against two hands, keeps the fixed reading: harness runs show that
## holding back every group nothing unseen beats costs it about five points of win rate.
func read_groups(other: Array[Pattern]) -> Controls:
	var counts_cards: bool = config.reads_the_table() and not is_landlord()
	return Controls.new(other, threats, _largest_opposing_hand(), table, counts_cards)


## A repeatable roll for this decision, from 0 to 1.
func roll() -> float:
	return _roll(0)


## True when this decision is one the bot doesn't try on, from its own salted roll so it
## never moves with the cooperation roll.
func slacks() -> bool:
	return config.effort < 1.0 and _roll(SLACK_SALT) >= config.effort


func _roll(salt: int) -> float:
	var state: int = CountKey.encode(view.own_counts) ^ (view.public.history.size() << 8)
	return RandomStream.new(config.search_seed ^ state ^ salt).next_float()


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


## With no hand shown, every unseen card. Otherwise a shown opponent's cards, plus the
## cards nobody showed when the seat that holds them is an opponent too.
func _threats() -> PackedByteArray:
	if view.exposed.is_empty():
		return unseen
	var hidden: PackedByteArray = unseen.duplicate()
	var opposing: PackedByteArray = PackedByteArray()
	opposing.resize(Ranks.COUNT)
	for shown_seat: int in view.exposed:
		var shown: PackedByteArray = view.exposed[shown_seat]
		for rank: int in Ranks.COUNT:
			hidden[rank] -= mini(hidden[rank], shown[rank])
			if is_opponent(shown_seat):
				opposing[rank] += shown[rank]
	for other: int in Seats.COUNT:
		if other != seat and not view.exposed.has(other) and is_opponent(other):
			for rank: int in Ranks.COUNT:
				opposing[rank] += hidden[rank]
			break
	return opposing


func _largest_opposing_hand() -> int:
	var largest: int = 0
	for other: int in Seats.COUNT:
		if is_opponent(other):
			largest = maxi(largest, view.public.remaining[other])
	return largest
