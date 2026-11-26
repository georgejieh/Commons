extends GdUnitTestSuite
## ADR 0021's Campaigns at the round's own API: a trade one for one keeps every hand's
## size and the public counts, a kitty card that leaves the landlord leaves the public
## kitty, a mark lands on the live card, Mutual Aid's villager gives its lowest loose
## cards, and Seizure Notice picks its seat and its cards by the stated rule.

var _rules: RuleSet = RuleSet.default_rules()
var _map: PackedByteArray = Ranks.identity_map()
var _table: SeatRules = SeatRules.uniform(_rules, _map)


func _round(texts: Array[String], kitty: String, landlord: int) -> RoundState:
	return RoundState.new(RoundScript.stacked_deal(texts, kitty), landlord, _table)


func _context(round_state: RoundState, card_ids: Array[int] = []) -> CampaignContext:
	var context: CampaignContext = CampaignContext.new()
	context.state = RunState.new(5)
	context.round_state = round_state
	context.table = _table
	context.stack = ModifierStack.new()
	context.meters = RunDefaults.METERS
	context.params = RunDefaults.PARAMS
	context.flags = CampaignRound.new()
	context.set_log = SetLog.new()
	context.moment = CampaignContext.Moment.TURN
	context.card_ids = card_ids
	return context


func _ranks(round_state: RoundState, seat: int) -> String:
	var counts: PackedByteArray = round_state.view_for(seat).own_counts
	var text: String = ""
	for rank: int in Ranks.COUNT:
		text += RankText.SYMBOLS[rank].repeat(counts[rank])
	return text


func _id_of(round_state: RoundState, seat: int, rank: int) -> int:
	for card: CardInstance in round_state.view_for(seat).own_cards:
		if card.base_rank() == rank:
			return card.id()
	return -1


func test_a_trade_keeps_sizes_and_moves_the_cards() -> void:
	var round_state: RoundState = _round(["345", "678", "9TJ"], "", 0)
	var given: Array[int] = [_id_of(round_state, 0, Ranks.THREE)]
	var taken: Array[int] = [_id_of(round_state, 1, Ranks.EIGHT)]
	assert_int(round_state.trade(0, given, 1, taken)).is_equal(RoundState.Reason.OK)
	assert_str(_ranks(round_state, 0)).is_equal("458")
	assert_str(_ranks(round_state, 1)).is_equal("367")
	assert_array(Array(round_state.remaining())).is_equal([3, 3, 3])
	assert_array(Array(round_state.public_view().remaining)).is_equal([3, 3, 3])


func test_a_refused_trade_changes_nothing() -> void:
	var round_state: RoundState = _round(["345", "678", "9TJ"], "", 0)
	var mine: Array[int] = [_id_of(round_state, 0, Ranks.THREE)]
	var not_theirs: Array[int] = [_id_of(round_state, 2, Ranks.NINE)]
	assert_int(round_state.trade(0, mine, 1, not_theirs)).is_equal(RoundState.Reason.UNKNOWN_CARD)
	var twice: Array[int] = [mine[0], mine[0]]
	var two: Array[int] = [_id_of(round_state, 1, Ranks.SIX), _id_of(round_state, 1, Ranks.SEVEN)]
	assert_int(round_state.trade(0, twice, 1, two)).is_equal(RoundState.Reason.REPEATED_CARD)
	var none: Array[int] = []
	assert_int(round_state.trade(0, mine, 1, none)).is_not_equal(RoundState.Reason.OK)
	assert_str(_ranks(round_state, 0)).is_equal("345")
	assert_str(_ranks(round_state, 1)).is_equal("678")


## The expert deals the unplayed kitty to the landlord; a kitty card seized from them
## must leave the public kitty, or the search would believe the landlord still held it.
func test_a_kitty_card_that_leaves_the_landlord_leaves_the_public_kitty() -> void:
	var round_state: RoundState = _round(["345", "678", "9TJ"], "2", 1)
	assert_int(round_state.public_view().kitty_counts[Ranks.TWO]).is_equal(1)
	var given: Array[int] = [_id_of(round_state, 0, Ranks.THREE)]
	var taken: Array[int] = [_id_of(round_state, 1, Ranks.TWO)]
	round_state.trade(0, given, 1, taken)
	assert_int(round_state.public_view().kitty_counts[Ranks.TWO]).is_equal(0)
	var view: SeatView = round_state.view_for(2)
	var config: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.EXPERT)
	var table: BotTable = BotTable.new(_rules, _map)
	var scorer: CandidateScorer = CandidateScorer.new(view.own_counts, table, config.weights)
	var position: BotPosition = BotPosition.new(view, table, config, scorer)
	for sample: int in 8:
		var hands: Array[PackedByteArray] = ExpertSearch.deal_unseen(position, sample)
		assert_bool(hands.is_empty()).is_false()
		var size: int = 0
		for rank: int in Ranks.COUNT:
			size += hands[1][rank]
		assert_int(size).is_equal(round_state.remaining()[1])


func test_a_mark_lands_on_the_live_card() -> void:
	var round_state: RoundState = _round(["345", "678", "9TJ"], "", 0)
	var context: CampaignContext = _context(round_state, [_id_of(round_state, 0, Ranks.FOUR)])
	context.mark_chosen(CardInstance.MODEL)
	for card: CardInstance in round_state.view_for(0).own_cards:
		var model: bool = card.enhancement_id() == CardInstance.MODEL
		assert_bool(model).is_equal(card.base_rank() == Ranks.FOUR)
	assert_bool(context.state.card_marks.enhancements.has(context.card_ids[0])).is_true()


## Mutual Aid's villager gives its lowest cards that stand alone, never part of a pair,
## a trio or a rocket, and makes up the count from its lowest others.
func test_the_teammate_gives_its_lowest_loose_cards() -> void:
	var round_state: RoundState = _round(["3", "3449Ksb", "5"], "", 0)
	var view: SeatView = round_state.view_for(1)
	var gift: Array[int] = AidChoice.choose(view, _map, 2)
	var ranks: Array[int] = []
	for card: CardInstance in view.own_cards:
		if gift.has(card.id()):
			ranks.append(card.base_rank())
	ranks.sort()
	assert_array(ranks).is_equal([Ranks.THREE, Ranks.NINE])
	var paired: RoundState = _round(["3", "4455sb", "5"], "", 0)
	var short: Array[int] = AidChoice.choose(paired.view_for(1), _map, 2)
	var short_ranks: Array[int] = []
	for card: CardInstance in paired.view_for(1).own_cards:
		if short.has(card.id()):
			short_ranks.append(card.base_rank())
	assert_array(short_ranks).contains_exactly_in_any_order([Ranks.FOUR, Ranks.FOUR])


func test_mutual_aid_trades_with_the_teammate_only_as_a_peasant() -> void:
	var round_state: RoundState = _round(["3456", "789T", "JQKA"], "", 2)
	var mine: Array[int] = [_id_of(round_state, 0, Ranks.THREE), _id_of(round_state, 0, Ranks.FOUR)]
	var context: CampaignContext = _context(round_state, mine)
	var effect: MutualAidEffect = MutualAidEffect.new()
	assert_int(effect.check(context)).is_equal(CampaignEffect.Reason.OK)
	effect.apply(context)
	assert_str(_ranks(round_state, 0)).is_equal("5678")
	assert_str(_ranks(round_state, 1)).is_equal("349T")
	assert_str(_ranks(round_state, 2)).is_equal("JQKA")
	var landlord: RoundState = _round(["3456", "789T", "JQKA"], "", 0)
	var refused: CampaignContext = _context(landlord, mine)
	assert_int(effect.check(refused)).is_equal(CampaignEffect.Reason.NOT_PEASANT)


## As landlord, the seat taken from is the peasant holding more cards, the next seat on a
## tie; its highest card by its own order, the higher ID on a tie, for your lowest.
func test_seizure_takes_the_highest_card_from_the_fullest_opponent() -> void:
	var round_state: RoundState = _round(["3456", "789", "TJ2"], "", 0)
	var context: CampaignContext = _context(round_state)
	var effect: SeizureNoticeEffect = SeizureNoticeEffect.new()
	effect.parameters = {"resentment": 4}
	assert_int(SeizureNoticeEffect.target(context)).is_equal(1)
	effect.apply(context)
	assert_str(_ranks(round_state, 0)).is_equal("4569")
	assert_str(_ranks(round_state, 1)).is_equal("378")
	assert_int(context.state.resentment).is_equal(4)
	var tied: RoundState = _round(["3456", "78", "2T"], "", 0)
	var tied_context: CampaignContext = _context(tied)
	assert_int(SeizureNoticeEffect.target(tied_context)).is_equal(1)
	var as_peasant: RoundState = _round(["3456", "789TJ", "QK"], "", 2)
	assert_int(SeizureNoticeEffect.target(_context(as_peasant))).is_equal(2)


func test_seizure_is_refused_while_a_hand_in_the_trade_holds_one_card() -> void:
	var effect: SeizureNoticeEffect = SeizureNoticeEffect.new()
	var short_opponent: RoundState = _round(["3456", "7", "TJ2"], "", 1)
	assert_int(effect.check(_context(short_opponent))).is_equal(
		CampaignEffect.Reason.HAND_TOO_SMALL
	)
	var short_mine: RoundState = _round(["3", "78", "TJ2"], "", 1)
	assert_int(effect.check(_context(short_mine))).is_equal(CampaignEffect.Reason.HAND_TOO_SMALL)
	var fine: RoundState = _round(["34", "78", "TJ2"], "", 1)
	assert_int(effect.check(_context(fine))).is_equal(CampaignEffect.Reason.OK)
