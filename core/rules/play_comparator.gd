class_name PlayComparator
extends RefCounted
## Decides whether one play beats another, by its reading (ADR 0029). Tiers settle mixed
## matchups; inside a tier the comparison key does. Bombs order by size, then kind (a
## pure-wild bomb above a natural one above a soft one), then rank: with no bigger bombs
## every bomb has four cards, so the kinds of rule 5 decide, and with them more cards win
## whatever the kind (rule 6). The rocket beats every bomb, unless the rules put the
## pure-wild bomb above it, when the pure-wild bomb sits above the rocket and the rocket
## above every other bomb, so the order stays total.

## Tiers of play, low to high. A play beats one of a lower tier whatever its shape.
enum Tier { PLAIN, BOMB, TOP, ABOVE_TOP }
## Bomb kinds, low to high.
enum BombKind { SOFT, NATURAL, PURE_WILD }

## A pure-wild bomb is exactly this many cards of one wild rank (rule 5).
const PURE_WILD_CARDS: int = 4


static func beats(play: Pattern, current: Pattern, rules: RuleSet) -> bool:
	if play.type == Pattern.Type.PASS:
		return false
	if current.type == Pattern.Type.PASS:
		return true
	var play_tier: Tier = tier(play, rules)
	var current_tier: Tier = tier(current, rules)
	if play_tier != current_tier:
		return play_tier > current_tier
	if play_tier == Tier.PLAIN and play.shape() != current.shape():
		return false
	if play.type == Pattern.Type.ROCKET:
		return false
	if play.type == Pattern.Type.BOMB and play.card_count == current.card_count:
		var kind: BombKind = bomb_kind(play)
		var other: BombKind = bomb_kind(current)
		if kind != other:
			return kind > other
	return play.key > current.key


## Rule 5's kinds: soft with any stand-in, pure-wild for exactly four cards of a wild rank
## read as that rank, natural otherwise. Whether the rank is wild is the playing seat's
## to say (Pattern.main_wild): a villager's four of the player's wild rank are a natural
## bomb, and the player's four are pure-wild against anyone (ADR 0039).
static func bomb_kind(bomb: Pattern) -> BombKind:
	if bomb.stand_ins() > 0:
		return BombKind.SOFT
	if bomb.card_count == PURE_WILD_CARDS and bomb.main_wild:
		return BombKind.PURE_WILD
	return BombKind.NATURAL


## The rocket and a pure-wild bomb above it are the top tiers, in the order the rules set.
static func tier(pattern: Pattern, rules: RuleSet) -> Tier:
	if pattern.type == Pattern.Type.ROCKET:
		return Tier.ABOVE_TOP if rules.rocket_above_wild_bomb() else Tier.TOP
	if pattern.type != Pattern.Type.BOMB:
		return Tier.PLAIN
	if not rules.rocket_above_wild_bomb() and bomb_kind(pattern) == BombKind.PURE_WILD:
		return Tier.ABOVE_TOP
	return Tier.BOMB
