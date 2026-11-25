extends GdUnitTestSuite
## The informant's reading of the opponents' hands (P4.9) reads each opponent's cards under
## that opponent's own rules (ADR 0039): a Cadre that lets the player play a short Straight
## or a two-pair run never shows a villager holding one, and the player's wild rank never
## makes a villager's card a stand-in (second note of 2026-11-24).

const PLAYER: int = 0


func _types(cadre: String, villager_text: String, wild: Array[int] = []) -> PackedInt32Array:
	var stack: ModifierStack = ModifierStack.new()
	if not cadre.is_empty():
		stack.add(ResourceLoader.load("res://data/modifiers/%s.tres" % cadre), PLAYER)
	var table: SeatRules = SeatRules.new(stack)
	table.set_wild_ranks(wild, PLAYER)
	var deal: DealResult = RoundScript.stacked_deal(["KK", villager_text, "QQ"], "")
	var round_state: RoundState = RoundState.new(deal, PLAYER, table)
	table.refresh()
	var info: InfoView = InfoReveal.build(
		round_state, PLAYER, InfoView.OPPONENT_TYPES, BotTable.of_seat(table, PLAYER)
	)
	return info.opponent_types[1]


func test_a_short_straight_the_player_may_play_is_not_shown_in_a_villagers_hand() -> void:
	var types: PackedInt32Array = _types("shock_brigade", "3456")
	assert_int(types[Pattern.Type.STRAIGHT]).is_equal(0)
	assert_int(types[Pattern.Type.SINGLE]).is_equal(4)


func test_a_two_pair_run_the_player_may_play_is_not_shown_in_a_villagers_hand() -> void:
	var types: PackedInt32Array = _types("double_share_plough", "3344")
	assert_int(types[Pattern.Type.PAIR_CHAIN]).is_equal(0)
	assert_int(types[Pattern.Type.PAIR]).is_equal(2)


## The player's 7 is wild; a villager's 7 beside a 9 is two Singles, not a Pair of 9s.
func test_a_villagers_card_of_the_players_wild_rank_is_shown_plain() -> void:
	var sevens: Array[int] = [Ranks.SEVEN]
	var types: PackedInt32Array = _types("", "79", sevens)
	assert_int(types[Pattern.Type.PAIR]).is_equal(0)
	assert_int(types[Pattern.Type.SINGLE]).is_equal(2)
