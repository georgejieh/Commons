class_name TournamentRun
extends RefCounted
## Plays one tournament between two named configurations. wild ranks (ADR 0029), drawn
## per deal from its own seeded stream so both games of a deal share them, and bigger
## bombs are in force for every seat when set.

const DUPLICATE: String = "duplicate"
const BIDDING: String = "bidding"
const CONFIGS: Dictionary[String, BotConfig.Tier] = {
	"easy": BotConfig.Tier.EASY,
	"medium": BotConfig.Tier.MEDIUM,
	"hard": BotConfig.Tier.HARD,
	"expert": BotConfig.Tier.EXPERT,
}
const MAX_WILD: int = 2
const WILD_STREAM: String = "wild"

var tally: TournamentTally = TournamentTally.new()
## Ranks wild in each game, 0 to 2, and whether five or more cards of a rank are a bomb.
var wild: int = 0
var big_bombs: bool = false
## One JSON line per game, kept only when asked for.
var log_lines: PackedStringArray = PackedStringArray()

var _first: String
var _second: String
var _first_seed: int
var _keep_log: bool
var _table: SeatRules = SeatRules.uniform(RuleSet.default_rules(), Ranks.identity_map())
var _configs: Dictionary[String, BotConfig] = {}


func _init(first: String, second: String, first_seed: int = 0, keep_log: bool = false) -> void:
	_first = first
	_second = second
	_first_seed = first_seed
	_keep_log = keep_log
	for name: String in [first, second]:
		_configs[name] = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, CONFIGS[name])


## Plays each deal with the sides swapped, so games rounds down to an even number (ADR 0010).
func play_duplicate(games: int) -> void:
	@warning_ignore("integer_division")
	for deal: int in games / 2:
		var deal_seed: int = _first_seed + deal
		_play(DUPLICATE, deal_seed, 0, [_first, _second, _second])
		_play(DUPLICATE, deal_seed, 0, [_second, _first, _first])


## Lets bidding pick the landlord, with the first config in each seat in turn. A deal
## nobody claims is not a game, so this can play fewer than asked.
func play_bidding(games: int) -> void:
	for game: int in games:
		var game_seed: int = _first_seed + game
		var names: Array[String] = [_second, _second, _second]
		names[game % Seats.COUNT] = _first
		@warning_ignore("integer_division")
		var first_bidder: int = (game + game / Seats.COUNT) % Seats.COUNT
		var table: BotTable = BotTable.new(rules_for(game_seed), Ranks.identity_map())
		var bidding: Bidding = SelfPlay.bid_round(
			SelfPlay.deal_from_seed(game_seed), _seat_configs(names), table, first_bidder
		)
		if not bidding.needs_redeal():
			_play(BIDDING, game_seed, bidding.landlord(), names)


func _play(mode: String, game_seed: int, landlord: int, names: Array[String]) -> void:
	var deal: DealResult = SelfPlay.deal_from_seed(game_seed)
	var seats: Array[BotConfig] = _seat_configs(names)
	var table: SeatRules = _table
	if wild > 0 or big_bombs:
		table = SeatRules.uniform(rules_for(game_seed), Ranks.identity_map())
	var result: SelfPlayResult = SelfPlay.play_round(
		deal, landlord, seats, table, Time.get_ticks_usec
	)
	tally.add(mode, names, result)
	if _keep_log:
		log_lines.append(TournamentLog.line(game_seed, deal, names, result))


## The rules of one deal's games.
func rules_for(game_seed: int) -> RuleSet:
	if wild == 0 and not big_bombs:
		return RuleSet.default_rules()
	var params: RuleParams = RuleSet.DEFAULT_PARAMS.copy()
	params.five_plus_is_bomb = params.five_plus_is_bomb or big_bombs
	params.wild_ranks = wild_ranks_for(game_seed, wild)
	return RuleSet.new(params)


## count different ranks from 3 to 2, drawn from the deal's own wild stream.
static func wild_ranks_for(game_seed: int, count: int) -> Array[int]:
	var stream: RandomStream = RandomStream.new(RandomStreams.derive_seed(game_seed, WILD_STREAM))
	var ranks: Array[int] = []
	while ranks.size() < mini(count, MAX_WILD):
		var rank: int = stream.next_int(Ranks.THREE, Ranks.TWO)
		if not ranks.has(rank):
			ranks.append(rank)
	return ranks


func _seat_configs(names: Array[String]) -> Array[BotConfig]:
	var seats: Array[BotConfig] = []
	for name: String in names:
		seats.append(_configs[name])
	return seats
