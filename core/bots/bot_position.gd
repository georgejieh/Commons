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
## The cards this seat has not seen (UnseenCards). Counted only for a tier that reads the
## table, since no other tier looks at them; empty otherwise.
var unseen: PackedByteArray = PackedByteArray()
## The unseen cards an opponent could hold: all of them, unless a hand shown to the table
## (Glass Walls) tells the bot which of them a teammate holds or which seat holds what.
## Empty when unseen is.
var threats: PackedByteArray = PackedByteArray()
## How many of the threats are wild cards (ADR 0029).
var wild_threats: int = 0
var groups: Array[Pattern]
var controls: Controls
## The opponents' tables where they play under other rules or another order than this
## seat (ADR 0039), one for each way of playing; empty when they all play as it does.
var rivals: Array[BotTable] = []
## The tables this seat's own bomb is judged under once it is down, or null when a bomb
## changes nothing (BombedSide).
var bombed: BombedSide = null
## Which of the threats are wild: the opponents' rules (Controls.threat_rules).
var _threat_rules: RuleSet


## A repeatable roll from 0 to 1 for the decision the view stands at, apart from every
## other roll of it by its salt.
static func roll_for(seat_view: SeatView, bot_config: BotConfig, salt: int) -> float:
	var state: int = CountKey.encode(seat_view.own_counts) ^ (seat_view.public.history.size() << 8)
	return RandomStream.new(bot_config.search_seed ^ state ^ salt).next_float()


func _init(
	seat_view: SeatView, seat_table: BotTable, bot_config: BotConfig, scorer_in: CandidateScorer
) -> void:
	view = seat_view
	table = seat_table
	config = bot_config
	scorer = scorer_in
	seat = view.seat
	_read_seats()
	var counts_cards: bool = config.reads_the_table()
	if counts_cards:
		unseen = UnseenCards.from_view(view)
		threats = _threats()
	groups = scorer.decompose_own_hand().groups
	rivals = _rivals()
	_threat_rules = Controls.threat_rules(table, rivals)
	if counts_cards:
		var supply: WildSupply = WildSupply.of(threats, _threat_rules)
		wild_threats = 0 if supply == null else supply.total
	bombed = BombedSide.of(table, seat, _opponents())
	var largest: int = _largest_opposing_hand()
	controls = Controls.new(groups, threats, largest, table, counts_cards, rivals, bombed)


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
	var largest: int = _largest_opposing_hand()
	return Controls.new(other, threats, largest, table, counts_cards, rivals, bombed)


## A repeatable roll for this decision, from 0 to 1.
func roll() -> float:
	return roll_for(view, config, 0)


func rank_of(rank: int) -> int:
	return table.rank_map[rank]


## True when an opponent's other would stand above this seat's rank, each read in its own
## seat's order on the shared standings (ADR 0039).
func outranked(other: int, rank: int) -> bool:
	var own: int = table.standing[rank]
	if rivals.is_empty():
		return table.standing[other] > own
	for rival: BotTable in rivals:
		if rival.standing[other] > own:
			return true
	return false


## True when an opponent could hold width cards that read as rank, counting the threats
## by the cards really spent. A wild card joins any rank from 3 to 2 that has a card of
## its own, so it never makes a single on its own (ADR 0029, rule 2).
func could_hold(rank: int, width: int) -> bool:
	if threats[rank] >= width:
		return true
	if wild_threats == 0 or threats[rank] == 0 or rank > Ranks.TWO:
		return false
	var others: int = wild_threats - (threats[rank] if _threat_rules.is_wild(rank) else 0)
	return threats[rank] + others >= width


func _read_seats() -> void:
	teammate = Seats.teammate(seat, view.public.landlord)
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


func _rivals() -> Array[BotTable]:
	var found: Array[BotTable] = []
	if table.is_uniform():
		return found
	var differs: bool = false
	for other: int in Seats.COUNT:
		if not is_opponent(other):
			continue
		var rival: BotTable = table.as_seat(other, table.bombed)
		if _plays_like(rival, table):
			rival = table
		else:
			differs = true
		if not found.any(func(known: BotTable) -> bool: return _plays_like(known, rival)):
			found.append(rival)
	if not differs:
		found.clear()
	return found


func _opponents() -> Array[int]:
	var found: Array[int] = []
	for other: int in Seats.COUNT:
		if is_opponent(other):
			found.append(other)
	return found


static func _plays_like(first: BotTable, second: BotTable) -> bool:
	return first.rules == second.rules and first.standing == second.standing


func _largest_opposing_hand() -> int:
	var largest: int = 0
	for other: int in Seats.COUNT:
		if is_opponent(other):
			largest = maxi(largest, view.public.remaining[other])
	return largest
