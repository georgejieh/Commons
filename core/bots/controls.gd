class_name Controls
extends RefCounted
## Which of a hand's groups nothing unseen can beat, given what could still appear.

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
) -> void:
	rocket_possible = unseen[Ranks.SMALL_JOKER] > 0 and unseen[Ranks.BIG_JOKER] > 0
	for rank: int in Ranks.COUNT:
		if unseen[rank] >= BOMB_WIDTH:
			bomb_possible = true
	var mask: int = UnseenCards.mask_of(unseen)
	var controls: int = 0
	for group: Pattern in groups:
		var is_control: bool = _is_control(group, unseen, mask, largest_hand, table)
		flags.append(is_control)
		controls += 1 if is_control else 0
	effective_hands = groups.size() - controls


## A rival must hold the whole answer, so an answer larger than any hand does not count.
func _is_control(
	group: Pattern, unseen: PackedByteArray, mask: int, largest_hand: int, table: BotTable
) -> bool:
	if group.type == Pattern.Type.ROCKET:
		return true
	if group.card_count > largest_hand and group.type != Pattern.Type.BOMB:
		return true
	var beaters: Array[Pattern] = MoveGenerator.generate(
		unseen, mask, group, table.rules, table.rank_map
	)
	for beater: Pattern in beaters:
		var same_type: bool = beater.type == group.type
		var answers_bomb: bool = group.type == Pattern.Type.BOMB
		if (same_type or answers_bomb) and beater.card_count <= largest_hand:
			return false
	return true
