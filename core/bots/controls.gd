class_name Controls
extends RefCounted
## Which of a hand's groups nothing unseen can beat, given what could still appear.
## A bot that doesn't count cards treats only 2s, jokers and bombs as controls. While a
## rank is wild, unseen wild cards can finish an answer of any rank (ADR 0029), which the
## move generator reads from the unseen counts. An answer is read under each rival's own
## rules and standings (ADR 0039): a group is beaten if any rival's could beat it. A bomb
## is judged as the trick will stand once it is down, under the standings that hold after
## a bomb (Cultural Revolution turns its holder's order over), when the caller gives them.

const BOMB_WIDTH: int = 4

## One flag per group of the decomposition.
var flags: Array[bool] = []
var bomb_possible: bool = false
var rocket_possible: bool = false
var effective_hands: int = 0


func _init(
	groups: Array[Pattern],
	unseen: PackedByteArray,
	largest_hand: int,
	table: BotTable,
	counts_cards: bool = true,
	rivals: Array[BotTable] = [],
	bombed: BombedSide = null,
) -> void:
	var answering: Array[BotTable] = rivals
	if answering.is_empty():
		answering = [table]
	rocket_possible = unseen[Ranks.SMALL_JOKER] > 0 and unseen[Ranks.BIG_JOKER] > 0
	var wild_rules: RuleSet = threat_rules(table, rivals)
	var supply: WildSupply = WildSupply.of(unseen, wild_rules)
	var wilds: int = 0 if supply == null else supply.total
	for rank: int in Ranks.COUNT:
		if unseen[rank] >= BOMB_WIDTH:
			bomb_possible = true
		elif wilds > 0 and rank <= Ranks.TWO and unseen[rank] > 0:
			var others: int = wilds - (unseen[rank] if wild_rules.is_wild(rank) else 0)
			bomb_possible = bomb_possible or unseen[rank] + others >= BOMB_WIDTH
	var mask: int = UnseenCards.mask_of(unseen)
	var controls: int = 0
	for group: Pattern in groups:
		var high: bool = table.rank_map[group.main_rank] >= Ranks.TWO
		var is_control: bool = high or group.type == Pattern.Type.BOMB
		if counts_cards:
			var own: BotTable = table
			var against: Array[BotTable] = answering
			if group.type == Pattern.Type.BOMB and bombed != null:
				own = bombed.own
				against = bombed.rivals
			is_control = _is_control(group, unseen, mask, largest_hand, own, against)
		flags.append(is_control)
		controls += 1 if is_control else 0
	effective_hands = groups.size() - controls


## The rules that say which unseen cards are wild: the opponents', since a wild rank may
## be one seat's alone (ADR 0039), so the player's wild rank makes no villager's card a
## threat and a villager bot still fears the player's. Of the rivals, the one with the
## most wild ranks; with none, every seat plays as this one.
static func threat_rules(table: BotTable, rivals: Array[BotTable]) -> RuleSet:
	var found: RuleSet = table.rules
	for index: int in rivals.size():
		var rival: RuleSet = rivals[index].rules
		if index == 0 or rival.wild_ranks().size() > found.wild_ranks().size():
			found = rival
	return found


## A rival must hold the whole answer, so an answer larger than any hand does not count.
func _is_control(
	group: Pattern,
	unseen: PackedByteArray,
	mask: int,
	largest_hand: int,
	table: BotTable,
	answering: Array[BotTable]
) -> bool:
	if group.type == Pattern.Type.ROCKET:
		return true
	if group.card_count > largest_hand and group.type != Pattern.Type.BOMB:
		return true
	var played: Pattern = group.rekeyed(table.standing[group.main_rank])
	for rival: BotTable in answering:
		var beaters: Array[Pattern] = MoveGenerator.generate(
			unseen, mask, played, rival.rules, rival.standing
		)
		for beater: Pattern in beaters:
			var same_type: bool = beater.type == group.type
			var answers_bomb: bool = group.type == Pattern.Type.BOMB
			if (same_type or answers_bomb) and beater.card_count <= largest_hand:
				return false
	return true
