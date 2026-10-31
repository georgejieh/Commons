class_name BotScript
extends RefCounted
## Builds table positions for bot tests. Plays are text, and an empty string is a pass.


static func round_after(
	seats: Array[String], plays: Array[String] = [], landlord: int = 0
) -> RoundState:
	var rules: RuleSet = RuleSet.default_rules()
	var map: PackedByteArray = Ranks.identity_map()
	var round_state: RoundState = RoundState.new(
		RoundScript.stacked_deal(seats, ""), landlord, SeatRules.uniform(rules, map)
	)
	for text: String in plays:
		if text.is_empty():
			round_state.apply(RoundAction.new(round_state.seat_to_act()))
		else:
			round_state.apply(RoundScript.play(round_state, text))
	return round_state


## What the seat to act decides.
static func decide(
	seats: Array[String],
	plays: Array[String] = [],
	landlord: int = 0,
	config: BotConfig = BotConfig.new()
) -> BotPlay:
	var round_state: RoundState = round_after(seats, plays, landlord)
	var seat: int = round_state.seat_to_act()
	var table: BotTable = BotTable.new(RuleSet.default_rules(), Ranks.identity_map())
	return Bot.decide_play(
		round_state.view_for(seat), round_state.legal_moves(), table, config, BotBudget.unlimited()
	)


static func text_of(play: BotPlay) -> String:
	if play.is_pass():
		return ""
	var counts: PackedByteArray = play.pattern.counts()
	var text: String = ""
	for rank: int in Ranks.COUNT:
		for _copy: int in counts[rank]:
			text += RankText.SYMBOLS[rank]
	return text
