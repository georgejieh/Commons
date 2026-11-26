extends GdUnitTestSuite
## ADR 0027's strategies at a real shop visit, through the controller's commands: each
## buys from the deck stall and the desks what its policy says and nothing else, every
## purchase is accepted, a deck card bought takes the place of the deck's weakest card and
## leaves the deck at 54, a desk's mark goes on the card the policy names, and the same
## seed spends the same way twice.

const SEED: int = 31
## Enough for every strategy to reach the deck's goods after all it buys first.
const COUPONS: int = 200
## Purchases one visit may make before the test calls it a loop.
const MOST_STEPS: int = 40

var _resentment_rises: Array[int] = []


func _at_the_shops(seed_value: int) -> RunController:
	var loop: RunLoop = RunLoop.new(RunState.new(seed_value), RunScript.bots(), SetConfig.new())
	loop.start_set()
	RunScript.new().play_until_set_over(loop)
	loop.state.coupons = COUPONS
	assert_int(loop.open_shop()).is_equal(RunLoop.Reason.OK)
	var controller: RunController = auto_free(RunController.new())
	controller.live_search = false
	controller.resume(loop)
	return controller


## Plays the visit's purchases as the driver does, the Directive aside, checking each deck
## good against the deck before and after it; returns what was bought, in order.
func _spend(controller: RunController, strategy_name: String) -> Array[BalanceOffer]:
	var strategy: BalanceStrategy = BalanceDriver.strategy_named(strategy_name)
	var bought: Array[BalanceOffer] = []
	var market_bought: int = 0
	_resentment_rises.clear()
	for step: int in MOST_STEPS:
		var opened: EnvelopeShelf = controller.store.opened_envelope()
		if opened != null:
			assert_int(BalanceShop.keep_from(controller, opened)).is_equal(RunController.OK)
			continue
		var state: RunState = controller.state_copy()
		var visit: BalanceVisit = BalanceShop.visit(controller, state)
		visit.directive_bought = true
		visit.market_bought = market_bought
		var offer: BalanceOffer = strategy.purchase(visit)
		if offer == null:
			return bought
		var before: Array[CardInstance] = controller.store.deck_cards()
		var incoming: CardInstance = null
		if offer.kind == BalanceOffer.Kind.DECK_CARD:
			incoming = controller.store.deck_stall().card(offer.slot)
		var reason: int = BalanceShop.buy(controller, offer, Ranks.INVALID)
		assert_int(reason).override_failure_message("%s refused" % strategy_name).is_equal(
			RunController.OK
		)
		if offer.kind == BalanceOffer.Kind.DECK_CARD:
			_check_exchange(before, controller.store.deck_cards(), offer.card, incoming)
		elif offer.kind == BalanceOffer.Kind.MARK:
			_check_mark(before, controller.store.deck_cards(), offer)
			_resentment_rises.append(controller.state_copy().resentment - state.resentment)
		if offer.market:
			market_bought += 1
		bought.append(offer)
	fail("the visit did not end within %d purchases" % MOST_STEPS)
	return bought


## The card that went out was the first of the lowest rank the deck held, the one that
## came in ranks above it, and the deck still holds 54.
func _check_exchange(
	before: Array[CardInstance], after: Array[CardInstance], out: int, incoming: CardInstance
) -> void:
	assert_int(after.size()).is_equal(Deck.SIZE)
	for card: CardInstance in before:
		assert_int(before[out].base_rank()).is_less_equal(card.base_rank())
		if card.base_rank() == before[out].base_rank():
			assert_int(out).is_less_equal(card.id())
	assert_int(incoming.base_rank()).is_greater(before[out].base_rank())
	assert_int(after[out].base_rank()).is_equal(incoming.base_rank())
	assert_int(after[out].suit()).is_equal(incoming.suit())


## The mark went on the highest card that had no mark of the desk's kind, the lowest slot
## on a tie, and nothing else changed.
func _check_mark(
	before: Array[CardInstance], after: Array[CardInstance], offer: BalanceOffer
) -> void:
	var stamps: bool = offer.market
	for card: CardInstance in before:
		var marked: bool = (
			card.owner_stamp() != CardInstance.NO_OWNER
			if stamps
			else card.enhancement_id() != CardInstance.NO_ID
		)
		if marked or card.id() == offer.card:
			continue
		assert_int(card.base_rank()).is_less_equal(before[offer.card].base_rank())
		if card.base_rank() == before[offer.card].base_rank():
			assert_int(card.id()).is_greater(offer.card)
	if stamps:
		assert_int(after[offer.card].owner_stamp()).is_equal(RunLoop.PLAYER)
	else:
		assert_str(after[offer.card].enhancement_id()).is_equal(offer.item_id)


func _kinds(bought: Array[BalanceOffer], market: bool) -> Array[int]:
	var kinds: Array[int] = []
	for offer: BalanceOffer in bought:
		if offer.market == market:
			kinds.append(offer.kind)
	return kinds


func test_collective_buys_the_deck_goods_last_and_never_the_stamp() -> void:
	var bought: Array[BalanceOffer] = _spend(_at_the_shops(SEED), "collective")
	var kinds: Array[int] = _kinds(bought, false)
	assert_array(_kinds(bought, true)).is_empty()
	assert_array(kinds).contains([BalanceOffer.Kind.DECK_CARD, BalanceOffer.Kind.MARK])
	assert_int(kinds.count(BalanceOffer.Kind.MARK)).is_equal(1)
	var first_deck_good: int = kinds.find(BalanceOffer.Kind.DECK_CARD)
	for at: int in kinds.size():
		var deck_good: bool = kinds[at] in [BalanceOffer.Kind.DECK_CARD, BalanceOffer.Kind.MARK]
		assert_bool(deck_good).is_equal(at >= first_deck_good)
	assert_int(kinds[-1]).is_equal(BalanceOffer.Kind.MARK)
	assert_array(_resentment_rises).contains_exactly([0])


func test_private_takes_the_stamp_once_after_the_cadres_and_its_resentment() -> void:
	var bought: Array[BalanceOffer] = _spend(_at_the_shops(SEED), "private")
	assert_array(_kinds(bought, false)).is_empty()
	var kinds: Array[int] = _kinds(bought, true)
	assert_int(kinds.count(BalanceOffer.Kind.MARK)).is_equal(1)
	var stamp: int = kinds.find(BalanceOffer.Kind.MARK)
	for at: int in kinds.size():
		assert_bool(kinds[at] == BalanceOffer.Kind.CADRE).is_equal(at < stamp)
	assert_array(_resentment_rises).contains_exactly([RunDefaults.RESENTMENT.private_purchase])


func test_mixed_buys_the_deck_goods_and_one_thing_at_the_market() -> void:
	var bought: Array[BalanceOffer] = _spend(_at_the_shops(SEED), "mixed")
	assert_array(_kinds(bought, false)).contains(
		[BalanceOffer.Kind.DECK_CARD, BalanceOffer.Kind.MARK]
	)
	assert_int(_kinds(bought, true).size()).is_less_equal(1)


func test_the_same_seed_spends_the_same_twice() -> void:
	for strategy: String in BalanceDriver.STRATEGIES:
		var first: Array[BalanceOffer] = _spend(_at_the_shops(SEED), strategy)
		var again: Array[BalanceOffer] = _spend(_at_the_shops(SEED), strategy)
		assert_int(again.size()).is_equal(first.size())
		for at: int in mini(first.size(), again.size()):
			var a: BalanceOffer = first[at]
			var b: BalanceOffer = again[at]
			var same: bool = (
				a.kind == b.kind and a.slot == b.slot and a.card == b.card and a.market == b.market
			)
			assert_bool(same).override_failure_message("%s step %d" % [strategy, at]).is_true()
