class_name HandReference
extends RefCounted
## Brute-force fewest plays, for tests only: tries every legal lead that keeps to the
## search's groups. Trios and bombs stay whole outside chains, kickers come from whole
## singles and pairs, four-with-two is left out, and the rocket stays together.

const NO_PLAYS: int = 99

var _rules: RuleSet
var _map: PackedByteArray
var _memo: Dictionary[int, int] = {}


func _init(rules: RuleSet, rank_map: PackedByteArray) -> void:
	_rules = rules
	_map = rank_map


func fewest_plays(counts: PackedByteArray) -> int:
	var key: int = CountKey.encode(counts)
	if key == 0:
		return 0
	if _memo.has(key):
		return _memo[key]
	var mask: int = 0
	for rank: int in Ranks.COUNT:
		if counts[rank] > 0:
			mask |= 1 << rank
	var best: int = NO_PLAYS
	for move: Pattern in MoveGenerator.generate(counts, mask, null, _rules, _map):
		if _keeps_groups(move, counts):
			var rest: PackedByteArray = counts.duplicate()
			var used: PackedByteArray = move.counts()
			for rank: int in Ranks.COUNT:
				rest[rank] -= used[rank]
			best = mini(best, 1 + fewest_plays(rest))
	_memo[key] = best
	return best


func _keeps_groups(move: Pattern, counts: PackedByteArray) -> bool:
	var rocket: bool = counts[Ranks.SMALL_JOKER] > 0 and counts[Ranks.BIG_JOKER] > 0
	if rocket and move.main_rank >= Ranks.SMALL_JOKER and move.type != Pattern.Type.ROCKET:
		return false
	if not _body_is_whole(move, counts):
		return false
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(Ranks.COUNT)
	for rank: int in move.kicker_ranks:
		seen[rank] += 1
		if rocket and rank >= Ranks.SMALL_JOKER:
			return false
	for rank: int in Ranks.COUNT:
		if seen[rank] > 0 and counts[rank] != seen[rank]:
			return false
	return true


func _body_is_whole(move: Pattern, counts: PackedByteArray) -> bool:
	match move.type:
		Pattern.Type.FOUR_TWO_SINGLES, Pattern.Type.FOUR_TWO_PAIRS:
			return false
		Pattern.Type.SINGLE, Pattern.Type.PAIR, Pattern.Type.TRIO, Pattern.Type.BOMB:
			return counts[move.main_rank] == move.card_count
		Pattern.Type.TRIO_SINGLE, Pattern.Type.TRIO_PAIR:
			return counts[move.main_rank] == 3
	return true
