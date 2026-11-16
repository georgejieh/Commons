extends GdUnitTestSuite
## ADR 0027's three strategies, choice by choice, from plain values; the 90% Wilson
## interval; and the ordering verdict on hand-made tallies.

const TRUE_NEED: int = 10
const CAP: int = 40


func _strategy(strategy_name: String) -> BalanceStrategy:
	return BalanceDriver.strategy_named(strategy_name)


func _params() -> BalanceParams:
	return BalanceDriver.PARAMS


func _offer(kind: int, price: int, market: bool, slot: int = 0) -> BalanceOffer:
	return BalanceOffer.new(kind as BalanceOffer.Kind, slot, price, market)


## A visit with a Cadre, a Reform, an envelope and a Campaign at the store, and a Cadre,
## a Parcel, a plot card and an upgrade at the black market.
func _visit(coupons: int, resentment: int = 0) -> BalanceVisit:
	var visit: BalanceVisit = BalanceVisit.new()
	visit.coupons = coupons
	visit.resentment = resentment
	(
		visit
		. store
		. assign(
			[
				_offer(BalanceOffer.Kind.CADRE, 6, false, 0),
				_offer(BalanceOffer.Kind.CADRE, 8, false, 1),
				_offer(BalanceOffer.Kind.REFORM, 5, false),
				_offer(BalanceOffer.Kind.ENVELOPE, 3, false),
				_offer(BalanceOffer.Kind.CAMPAIGN, 2, false),
			]
		)
	)
	(
		visit
		. market
		. assign(
			[
				_offer(BalanceOffer.Kind.CADRE, 7, true),
				_offer(BalanceOffer.Kind.PARCEL, 4, true),
				_offer(BalanceOffer.Kind.PLOT_CARD, 3, true),
				_offer(BalanceOffer.Kind.UPGRADE, 5, true),
			]
		)
	)
	return visit


func _kind(offer: BalanceOffer) -> int:
	return -1 if offer == null else offer.kind


## The same visit with two Directives at the store, at 3 and 5 coupons.
func _with_directives(coupons: int, resentment: int = 0) -> BalanceVisit:
	var visit: BalanceVisit = _visit(coupons, resentment)
	visit.store.append(_offer(BalanceOffer.Kind.DIRECTIVE, 5, false, 0))
	visit.store.append(_offer(BalanceOffer.Kind.DIRECTIVE, 3, false, 1))
	return visit


func test_every_strategy_issues_the_cheapest_directive_first_once_a_visit() -> void:
	for name: String in BalanceDriver.STRATEGIES:
		var strategy: BalanceStrategy = _strategy(name)
		var first: BalanceOffer = strategy.purchase(_with_directives(50))
		assert_int(_kind(first)).override_failure_message(name).is_equal(
			BalanceOffer.Kind.DIRECTIVE
		)
		assert_int(first.slot).override_failure_message(name).is_equal(1)
		assert_bool(first.market).is_false()
		var issued: BalanceVisit = _with_directives(50)
		issued.directive_bought = true
		assert_int(_kind(strategy.purchase(issued))).override_failure_message(name).is_not_equal(
			BalanceOffer.Kind.DIRECTIVE
		)
	# Private buys nothing else at the state store: with a Directive issued, the market.
	var private_visit: BalanceVisit = _with_directives(50)
	private_visit.directive_bought = true
	assert_bool(_strategy("private").purchase(private_visit).market).is_true()
	# Collective, with too little for either Directive, buys down its own list.
	assert_int(_kind(_strategy("collective").purchase(_with_directives(2)))).is_equal(
		BalanceOffer.Kind.CAMPAIGN
	)


## The coupons mixed keeps back are for the black market, never held from a Directive.
func test_mixed_keeps_nothing_back_from_its_directive() -> void:
	var kept: int = _params().kept_back
	var mixed: BalanceStrategy = _strategy("mixed")
	var first: BalanceOffer = mixed.purchase(_with_directives(3))
	assert_int(_kind(first)).is_equal(BalanceOffer.Kind.DIRECTIVE)
	assert_int(first.slot).is_equal(1)
	assert_int(_kind(mixed.purchase(_with_directives(2)))).is_not_equal(BalanceOffer.Kind.DIRECTIVE)
	var issued: BalanceVisit = _with_directives(kept + 2)
	issued.directive_bought = true
	assert_int(_kind(mixed.purchase(issued))).is_not_equal(BalanceOffer.Kind.DIRECTIVE)
	assert_int(_kind(_strategy("collective").purchase(_with_directives(3)))).is_equal(
		BalanceOffer.Kind.DIRECTIVE
	)


func test_the_cheapest_offer_of_a_kind() -> void:
	var offers: Array[BalanceOffer] = _with_directives(0).store
	assert_int(BalanceOffer.cheapest(offers, BalanceOffer.Kind.DIRECTIVE, 9).price).is_equal(3)
	assert_object(BalanceOffer.cheapest(offers, BalanceOffer.Kind.DIRECTIVE, 2)).is_null()
	assert_int(BalanceOffer.cheapest(offers, BalanceOffer.Kind.CADRE, 9).price).is_equal(6)
	var ledger: BalanceLedger = BalanceLedger.new()
	assert_str(BalanceLedger.category(offers[-1])).is_equal("directives")
	ledger.shop_step("directives", 9, 6)
	ledger.shop_step("campaigns", 6, 10)
	assert_int(ledger.spent["directives"]).is_equal(3)
	assert_int(ledger.earned[BalanceLedger.OTHER]).is_equal(4)


func test_the_percentile_reads_between_values() -> void:
	var values: PackedFloat64Array = PackedFloat64Array([0.1, 0.2, 0.4, 1.0])
	assert_float(BalanceCurve.percentile(values, 0.5)).is_equal_approx(0.3, 0.0001)
	assert_float(BalanceCurve.percentile(values, 0.25)).is_equal_approx(0.175, 0.0001)
	assert_float(BalanceCurve.percentile(values, 1.0)).is_equal_approx(1.0, 0.0001)
	assert_float(BalanceCurve.percentile(PackedFloat64Array([0.7]), 0.75)).is_equal(0.7)


func test_the_sampled_weights_are_a_copy() -> void:
	var copy: BotWeights = BalanceDriver.sampling(12)
	assert_int(copy.expert_samples).is_equal(12)
	assert_int(copy.expert_min_samples).is_less_equal(12)
	assert_object(copy).is_not_same(BotConfig.DEFAULT_WEIGHTS)
	assert_int(BotConfig.DEFAULT_WEIGHTS.expert_samples).is_equal(48)


func test_the_seat_by_strategy() -> void:
	for is_grab: bool in [false, true]:
		for bot_calls: bool in [false, true]:
			assert_bool(_strategy("collective").bid(is_grab, bot_calls)).is_false()
			assert_bool(_strategy("private").bid(is_grab, bot_calls)).is_equal(bot_calls)
			var mixed: bool = bot_calls and not is_grab
			assert_bool(_strategy("mixed").bid(is_grab, bot_calls)).is_equal(mixed)


func test_the_need_by_strategy() -> void:
	assert_int(_strategy("collective").need(TRUE_NEED, CAP, 1)).is_equal(TRUE_NEED)
	assert_int(_strategy("private").need(TRUE_NEED, CAP, 3)).is_equal(CAP)
	var over: int = TRUE_NEED + roundi(TRUE_NEED * _params().over_claim_percent / 100.0)
	assert_int(_strategy("mixed").need(TRUE_NEED, CAP, 1)).is_equal(over)
	assert_int(_strategy("mixed").need(TRUE_NEED, CAP, 0)).is_equal(over)
	assert_int(_strategy("mixed").need(TRUE_NEED, CAP, 2)).is_equal(TRUE_NEED)


func test_collective_buys_at_the_store_in_the_table_order() -> void:
	var collective: BalanceStrategy = _strategy("collective")
	var dearest: BalanceOffer = collective.purchase(_visit(20))
	assert_int(_kind(dearest)).is_equal(BalanceOffer.Kind.CADRE)
	assert_int(dearest.slot).is_equal(1)
	assert_int(collective.purchase(_visit(7)).price).is_equal(6)
	assert_int(_kind(collective.purchase(_visit(5)))).is_equal(BalanceOffer.Kind.REFORM)
	assert_int(_kind(collective.purchase(_visit(4)))).is_equal(BalanceOffer.Kind.ENVELOPE)
	assert_int(_kind(collective.purchase(_visit(2)))).is_equal(BalanceOffer.Kind.CAMPAIGN)
	assert_object(collective.purchase(_visit(1))).is_null()
	# The black market alone is never entered.
	var market_only: BalanceVisit = _visit(50)
	market_only.store.clear()
	assert_object(collective.purchase(market_only)).is_null()


func test_private_buys_only_at_the_black_market() -> void:
	var private: BalanceStrategy = _strategy("private")
	var at_market: BalanceOffer = private.purchase(_visit(50))
	assert_bool(at_market.market).is_true()
	assert_int(_kind(at_market)).is_equal(BalanceOffer.Kind.CADRE)
	assert_int(_kind(private.purchase(_visit(6)))).is_equal(BalanceOffer.Kind.PARCEL)
	assert_int(_kind(private.purchase(_visit(3)))).is_equal(BalanceOffer.Kind.PLOT_CARD)
	var upgrades: BalanceVisit = _visit(50)
	upgrades.market = upgrades.market.filter(
		func(offer: BalanceOffer) -> bool: return offer.kind == BalanceOffer.Kind.UPGRADE
	)
	assert_int(_kind(private.purchase(upgrades))).is_equal(BalanceOffer.Kind.UPGRADE)
	assert_object(private.purchase(_visit(2))).is_null()


func test_private_rerolls_once_a_visit_when_nothing_was_affordable() -> void:
	var private: BalanceStrategy = _strategy("private")
	var empty: BalanceVisit = _visit(1)
	empty.market.clear()
	empty.can_reroll = true
	assert_bool(private.rerolls(empty)).is_true()
	empty.rerolled = true
	assert_bool(private.rerolls(empty)).is_false()
	empty.rerolled = false
	empty.market_bought = 1
	assert_bool(private.rerolls(empty)).is_false()
	for name: String in ["collective", "mixed"]:
		var visit: BalanceVisit = _visit(1)
		visit.market.clear()
		visit.can_reroll = true
		assert_bool(_strategy(name).rerolls(visit)).is_false()


func test_mixed_keeps_coupons_back_then_buys_one_thing_under_the_limit() -> void:
	var mixed: BalanceStrategy = _strategy("mixed")
	var kept: int = _params().kept_back
	# With 10 coupons it spends only what is above the coupons kept back.
	var store: BalanceOffer = mixed.purchase(_visit(kept + 6))
	assert_bool(store.market).is_false()
	assert_int(store.price).is_equal(6)
	# With nothing above them for the store, the black market gets its dearest thing.
	var market: BalanceOffer = mixed.purchase(_visit(kept + 1))
	assert_bool(market.market).is_true()
	assert_int(market.price).is_equal(5)
	var bought: BalanceVisit = _visit(kept + 1)
	bought.market_bought = 1
	assert_object(mixed.purchase(bought)).is_null()
	var limit: int = _params().resentment_limit
	assert_object(mixed.purchase(_visit(kept + 1, limit))).is_null()
	assert_bool(mixed.purchase(_visit(kept + 1, limit - 1)).market).is_true()


func test_collective_and_mixed_shun_two_campaigns() -> void:
	for name: String in ["collective", "mixed"]:
		for campaign_id: String in _params().shunned_campaigns:
			assert_bool(_strategy(name).uses_campaign(campaign_id)).is_false()
		assert_bool(_strategy(name).uses_campaign("grain_loan")).is_true()
	assert_bool(_strategy("private").uses_campaign("anonymous_letter")).is_true()
	assert_bool(_strategy("collective").swaps()).is_false()
	assert_bool(_strategy("private").swaps()).is_true()
	assert_bool(_strategy("mixed").swaps()).is_true()


func test_the_swap_trades_low_hand_cards_for_higher_plot_cards() -> void:
	var hand: Array[CardInstance] = [
		CardInstance.new(1, Ranks.KING, 0, CardInstance.Origin.DECK),
		CardInstance.new(2, Ranks.THREE, 0, CardInstance.Origin.DECK),
		CardInstance.new(3, Ranks.FIVE, 0, CardInstance.Origin.DECK),
	]
	var plot: Array[CardInstance] = [
		CardInstance.new(901, Ranks.FOUR, 1, CardInstance.Origin.PLOT),
		CardInstance.new(902, Ranks.ACE, 1, CardInstance.Origin.PLOT),
		CardInstance.new(903, Ranks.SIX, 1, CardInstance.Origin.PLOT),
	]
	var chosen: Array[Array] = BalanceStrategy.best_swap(hand, plot, 3, Ranks.identity_map())
	assert_array(chosen[0]).contains_exactly([2, 3])
	assert_array(chosen[1]).contains_exactly([902, 903])
	var limited: Array[Array] = BalanceStrategy.best_swap(hand, plot, 1, Ranks.identity_map())
	assert_array(limited[0]).contains_exactly([2])
	assert_array(limited[1]).contains_exactly([902])


func test_the_rank_picked_is_the_one_held_most() -> void:
	var counts: PackedByteArray = PackedByteArray()
	counts.resize(Ranks.COUNT)
	assert_int(BalanceCards.most_held(counts)).is_equal(Ranks.TWO)
	counts[Ranks.SEVEN] = 2
	counts[Ranks.NINE] = 2
	counts[Ranks.BIG_JOKER] = 3
	assert_int(BalanceCards.most_held(counts)).is_equal(Ranks.NINE)


func test_the_wilson_interval() -> void:
	var half: Vector2 = BalanceVerdict.wilson(50, 100)
	assert_float(half.x).is_equal_approx(0.4190, 0.0005)
	assert_float(half.y).is_equal_approx(0.5810, 0.0005)
	var none: Vector2 = BalanceVerdict.wilson(0, 300)
	assert_float(none.x).is_equal(0.0)
	assert_float(none.y).is_equal_approx(0.0089, 0.0005)
	var all: Vector2 = BalanceVerdict.wilson(20, 20)
	assert_float(all.y).is_equal(1.0)
	assert_float(all.x).is_equal_approx(0.8810, 0.0005)


func _judge(mixed: int, private: int, collective: int, runs: int = 300) -> BalanceVerdict:
	var survivals: Dictionary[String, Vector2i] = {
		"mixed": Vector2i(mixed, runs),
		"private": Vector2i(private, runs),
		"collective": Vector2i(collective, runs),
	}
	return BalanceVerdict.judge(survivals)


func test_the_ordering_passes_only_past_every_interval() -> void:
	var passing: BalanceVerdict = _judge(180, 120, 60)
	assert_bool(passing.passed).is_true()
	assert_array(passing.failed_gaps).is_empty()
	assert_str(passing.line()).starts_with("PASS")


func test_the_ordering_fails_on_each_gap() -> void:
	assert_array(_judge(125, 120, 60).failed_gaps).contains_exactly(["mixed > private"])
	assert_array(_judge(180, 65, 60).failed_gaps).contains_exactly(["private > collective"])
	assert_array(_judge(180, 120, 0).failed_gaps).contains_exactly(["collective > 0"])
	var reversed: BalanceVerdict = _judge(60, 120, 180)
	assert_array(reversed.failed_gaps).contains_exactly(["mixed > private", "private > collective"])
	assert_str(reversed.line()).starts_with("FAIL")
	assert_str(reversed.line()).contains("mixed > private")


func test_a_tie_fails() -> void:
	var tied: BalanceVerdict = _judge(120, 120, 120)
	assert_bool(tied.passed).is_false()
	assert_array(tied.failed_gaps).contains_exactly(["mixed > private", "private > collective"])


func test_a_tally_without_every_strategy_is_not_judged() -> void:
	var tally: BalanceTally = BalanceTally.new(["collective"])
	var run: BalanceResult = BalanceResult.new()
	run.strategy = "collective"
	run.survived = true
	tally.add(run)
	var verdict: BalanceVerdict = tally.verdict()
	assert_bool(verdict.passed).is_false()
	assert_array(verdict.missing).contains_exactly(["mixed", "private"])


func test_a_hand_made_tally_reads_its_runs() -> void:
	var tally: BalanceTally = BalanceTally.new()
	for index: int in 10:
		for name: String in BalanceDriver.STRATEGIES:
			var run: BalanceResult = BalanceResult.new()
			run.seed_value = 9 - index
			run.strategy = name
			run.survived = index < {"mixed": 9, "private": 5, "collective": 1}[name]
			run.outcome = Endings.STRUGGLED if run.survived else Endings.DEATH_FAMINE
			run.year = 8 if run.survived else 3
			tally.add(run)
	var failed: BalanceResult = BalanceResult.new()
	failed.strategy = "mixed"
	failed.failure = "bid refused (2) at Year 1"
	tally.add(failed)
	assert_int(tally.survivals()["mixed"].x).is_equal(9)
	assert_int(tally.survivals()["mixed"].y).is_equal(10)
	assert_int(tally.failures().size()).is_equal(1)
	assert_float(tally.outcome_share("private", Endings.DEATH_FAMINE)).is_equal_approx(0.5, 0.001)
	assert_float(tally.mean("collective", "year", Endings.DEATH_FAMINE)).is_equal_approx(3.0, 0.001)
	var rows: PackedStringArray = tally.csv().strip_edges().split("\n")
	assert_str(rows[0]).is_equal(BalanceResult.HEADER)
	assert_str(rows[1]).starts_with("0,collective,")
	assert_str(rows[2]).starts_with("0,private,")
	var report: String = BalanceReport.markdown(
		tally,
		{"seeds": 10, "first_seed": 0, "stake": 0, "minutes": 0.0, "jobs": 1, "wall_seconds": 1.0}
	)
	assert_str(report).contains("FAIL")
	assert_str(report).contains("fewer than the 300")
	assert_str(report).contains("bid refused")
