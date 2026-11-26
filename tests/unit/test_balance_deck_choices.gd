extends GdUnitTestSuite
## ADR 0027's strategies at the deck's counters, from plain values: collective buys the
## deck stall's cards and the state store's mark after everything else it buys there,
## private the black market's stamp after a Cadre, mixed both under its own limits; the
## card a desk marks and the card a deck card replaces; and where their coupons are
## counted.


func _offer(kind: int, price: int, market: bool, slot: int = 0) -> BalanceOffer:
	return BalanceOffer.new(kind as BalanceOffer.Kind, slot, price, market)


func _kind(offer: BalanceOffer) -> int:
	return -1 if offer == null else offer.kind


## A visit with the Directive issued: at the store a Cadre, a Campaign, two deck cards and
## the desk's mark; at the black market a Cadre, the desk's stamp and a dearer Parcel.
func _visit(coupons: int, resentment: int = 0) -> BalanceVisit:
	var visit: BalanceVisit = BalanceVisit.new()
	visit.coupons = coupons
	visit.resentment = resentment
	visit.directive_bought = true
	visit.store.append(_offer(BalanceOffer.Kind.CADRE, 6, false))
	visit.store.append(_offer(BalanceOffer.Kind.CAMPAIGN, 3, false))
	visit.store.append(_offer(BalanceOffer.Kind.DECK_CARD, 2, false, 0))
	visit.store.append(_offer(BalanceOffer.Kind.DECK_CARD, 4, false, 1))
	visit.store.append(_offer(BalanceOffer.Kind.MARK, 3, false))
	visit.market.append(_offer(BalanceOffer.Kind.CADRE, 7, true))
	visit.market.append(_offer(BalanceOffer.Kind.MARK, 3, true))
	visit.market.append(_offer(BalanceOffer.Kind.PARCEL, 5, true))
	return visit


## The visit with only the kinds kept, at each counter.
func _only(visit: BalanceVisit, kinds: Array[int]) -> BalanceVisit:
	var keep: Callable = func(offer: BalanceOffer) -> bool: return kinds.has(offer.kind)
	visit.store = visit.store.filter(keep)
	visit.market = visit.market.filter(keep)
	return visit


func test_collective_buys_the_deck_goods_last_the_dearest_card_first() -> void:
	var collective: BalanceStrategy = BalanceDriver.strategy_named("collective")
	assert_int(_kind(collective.purchase(_visit(50)))).is_equal(BalanceOffer.Kind.CADRE)
	var deck_only: BalanceVisit = _only(
		_visit(50), [BalanceOffer.Kind.DECK_CARD, BalanceOffer.Kind.MARK]
	)
	var card: BalanceOffer = collective.purchase(deck_only)
	assert_int(_kind(card)).is_equal(BalanceOffer.Kind.DECK_CARD)
	assert_int(card.slot).is_equal(1)
	# The dearer card is out of reach: the one it affords.
	assert_int(collective.purchase(_only(_visit(3), [BalanceOffer.Kind.DECK_CARD])).slot).is_equal(
		0
	)
	var mark: BalanceOffer = collective.purchase(_only(_visit(50), [BalanceOffer.Kind.MARK]))
	assert_int(_kind(mark)).is_equal(BalanceOffer.Kind.MARK)
	assert_bool(mark.market).is_false()


func test_collective_never_takes_the_black_markets_stamp() -> void:
	var collective: BalanceStrategy = BalanceDriver.strategy_named("collective")
	var market_only: BalanceVisit = _visit(50)
	market_only.store.clear()
	assert_object(collective.purchase(market_only)).is_null()


func test_private_takes_the_stamp_after_a_cadre_and_nothing_of_the_deck_at_the_store() -> void:
	var private: BalanceStrategy = BalanceDriver.strategy_named("private")
	assert_int(_kind(private.purchase(_visit(50)))).is_equal(BalanceOffer.Kind.CADRE)
	var no_cadre: BalanceVisit = _visit(50)
	no_cadre.market = no_cadre.market.filter(
		func(offer: BalanceOffer) -> bool: return offer.kind != BalanceOffer.Kind.CADRE
	)
	var stamp: BalanceOffer = private.purchase(no_cadre)
	# Before the dearer Parcel: the market order puts the stamp after a Cadre.
	assert_int(_kind(stamp)).is_equal(BalanceOffer.Kind.MARK)
	assert_bool(stamp.market).is_true()
	var store_only: BalanceVisit = _visit(50)
	store_only.market.clear()
	assert_object(private.purchase(store_only)).is_null()


func test_mixed_buys_the_deck_goods_and_the_stamp_under_its_limits() -> void:
	var mixed: BalanceStrategy = BalanceDriver.strategy_named("mixed")
	var deck_only: BalanceVisit = _only(
		_visit(50), [BalanceOffer.Kind.DECK_CARD, BalanceOffer.Kind.MARK]
	)
	assert_int(_kind(mixed.purchase(deck_only))).is_equal(BalanceOffer.Kind.DECK_CARD)
	var stamp_only: BalanceVisit = _visit(50)
	stamp_only.store.clear()
	stamp_only.market = stamp_only.market.filter(
		func(offer: BalanceOffer) -> bool: return offer.kind == BalanceOffer.Kind.MARK
	)
	assert_bool(mixed.purchase(stamp_only).market).is_true()
	stamp_only.market_bought = 1
	assert_object(mixed.purchase(stamp_only)).is_null()
	stamp_only.market_bought = 0
	stamp_only.resentment = BalanceDriver.PARAMS.resentment_limit
	assert_object(mixed.purchase(stamp_only)).is_null()


## A plain deck in slot order, every card a copy as RunStoreView.deck_cards() gives it.
func _deck() -> Array[CardInstance]:
	return Deck.new().cards()


func test_a_desk_marks_the_highest_card_without_its_mark_the_lowest_slot_on_a_tie() -> void:
	var deck: Array[CardInstance] = _deck()
	assert_int(BalanceShop.mark_target(deck, false)).is_equal(Deck.BIG_JOKER_ID)
	assert_int(BalanceShop.mark_target(deck, true)).is_equal(Deck.BIG_JOKER_ID)
	# An enhancement keeps the enhancing desk off the card, but not the stamping one.
	deck[Deck.BIG_JOKER_ID].set_enhancement(CardInstance.SHEAF)
	deck[Deck.SMALL_JOKER_ID].set_owner_stamp(RunLoop.PLAYER)
	assert_int(BalanceShop.mark_target(deck, false)).is_equal(Deck.SMALL_JOKER_ID)
	assert_int(BalanceShop.mark_target(deck, true)).is_equal(Deck.BIG_JOKER_ID)
	deck[Deck.SMALL_JOKER_ID].set_enhancement(CardInstance.MODEL)
	var two: int = BalanceShop.mark_target(deck, false)
	assert_int(deck[two].base_rank()).is_equal(Ranks.TWO)
	for card: CardInstance in deck:
		if card.base_rank() == Ranks.TWO:
			assert_int(two).is_less_equal(card.id())
	for card: CardInstance in deck:
		card.set_enhancement(CardInstance.PENNANT)
	assert_int(BalanceShop.mark_target(deck, false)).is_equal(RunController.NO_CARD)


func test_a_deck_card_replaces_the_first_card_of_the_lowest_rank() -> void:
	var deck: Array[CardInstance] = _deck()
	var out: int = BalanceShop.weakest_slot(deck)
	assert_int(deck[out].base_rank()).is_equal(Ranks.THREE)
	for card: CardInstance in deck:
		if card.base_rank() == Ranks.THREE:
			assert_int(out).is_less_equal(card.id())


func test_the_deck_goods_have_spending_of_their_own() -> void:
	var desk_at_market: BalanceOffer = _offer(BalanceOffer.Kind.MARK, 3, true)
	assert_str(BalanceLedger.category(desk_at_market)).is_equal("marks")
	assert_str(BalanceLedger.category(_offer(BalanceOffer.Kind.MARK, 3, false))).is_equal("marks")
	var card: BalanceOffer = _offer(BalanceOffer.Kind.DECK_CARD, 2, false)
	assert_str(BalanceLedger.category(card)).is_equal("deck_cards")
	assert_str(BalanceLedger.category(_offer(BalanceOffer.Kind.CADRE, 7, true))).is_equal("market")
	var run: BalanceResult = BalanceResult.new()
	run.ledger.shop_step("deck_cards", 9, 5)
	run.ledger.shop_step("marks", 5, 2)
	run.finish(RunState.new(1))
	assert_int(run.deck_spent).is_equal(4)
	assert_int(run.marks_spent).is_equal(3)
	var header: PackedStringArray = BalanceResult.HEADER.split(",")
	var cells: PackedStringArray = run.csv().split(",")
	assert_int(cells.size()).is_equal(header.size())
	assert_str(cells[header.find("deck_spent")]).is_equal("4")
	assert_str(cells[header.find("marks_spent")]).is_equal("3")
