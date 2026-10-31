class_name PlayComparator
extends RefCounted
## Decides whether one play beats another. Tiers settle mixed matchups; inside a tier
## the comparison key does, which orders bombs by size and then rank.

const TIER_PLAIN: int = 0
const TIER_BOMB: int = 1
const TIER_TOP: int = 2
const TIER_ABOVE_TOP: int = 3


static func beats(play: Pattern, current: Pattern, rules: RuleSet) -> bool:
	if play.type == Pattern.Type.PASS:
		return false
	if current.type == Pattern.Type.PASS:
		return true
	var play_tier: int = _tier(play, rules)
	var current_tier: int = _tier(current, rules)
	if play_tier != current_tier:
		return play_tier > current_tier
	if play_tier == TIER_PLAIN and play.shape() != current.shape():
		return false
	return play.key > current.key


## The rocket and a pure-wild bomb are the top two tiers, in the order the rules set.
static func _tier(pattern: Pattern, rules: RuleSet) -> int:
	if pattern.type == Pattern.Type.ROCKET:
		return TIER_ABOVE_TOP if rules.rocket_above_wild_bomb() else TIER_TOP
	if pattern.type != Pattern.Type.BOMB:
		return TIER_PLAIN
	if not rules.is_wild(pattern.main_rank):
		return TIER_BOMB
	return TIER_TOP if rules.rocket_above_wild_bomb() else TIER_ABOVE_TOP
