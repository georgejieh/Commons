class_name TournamentRun
extends RefCounted
## Plays one tournament between two named configurations.

const DUPLICATE: String = "duplicate"
const BIDDING: String = "bidding"
const CONFIGS: Dictionary[String, BotConfig.Tier] = {
	"easy": BotConfig.Tier.EASY,
	"medium": BotConfig.Tier.MEDIUM,
	"hard": BotConfig.Tier.HARD,
	"expert": BotConfig.Tier.EXPERT,
}

var tally: TournamentTally = TournamentTally.new()
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
	var table: BotTable = BotTable.new(RuleSet.default_rules(), Ranks.identity_map())
	for game: int in games:
		var game_seed: int = _first_seed + game
		var names: Array[String] = [_second, _second, _second]
		names[game % Seats.COUNT] = _first
		@warning_ignore("integer_division")
		var first_bidder: int = (game + game / Seats.COUNT) % Seats.COUNT
		var bidding: Bidding = SelfPlay.bid_round(
			SelfPlay.deal_from_seed(game_seed), _seat_configs(names), table, first_bidder
		)
		if not bidding.needs_redeal():
			_play(BIDDING, game_seed, bidding.landlord(), names)


func _play(mode: String, game_seed: int, landlord: int, names: Array[String]) -> void:
	var deal: DealResult = SelfPlay.deal_from_seed(game_seed)
	var seats: Array[BotConfig] = _seat_configs(names)
	var result: SelfPlayResult = SelfPlay.play_round(
		deal, landlord, seats, _table, Time.get_ticks_usec
	)
	tally.add(mode, names, result)
	if _keep_log:
		log_lines.append(TournamentLog.line(game_seed, deal, names, result))


func _seat_configs(names: Array[String]) -> Array[BotConfig]:
	var seats: Array[BotConfig] = []
	for name: String in names:
		seats.append(_configs[name])
	return seats
