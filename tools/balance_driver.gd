class_name BalanceDriver
extends RefCounted
## Plays one full run to its end through RunController, as the app starts one (ADR 0027):
## no profile, every unlock tier open, the Poor Peasants, the given stake. It answers
## whatever the run awaits: the Hard bot plays the player's cards from the player's seat
## view, as it would a villager's, and the strategy makes every other choice. Expert
## villagers search with no limit, so a seed plays the same each time (ADR 0030). A
## refused command, a bot action the round refused, a script error or a run past the
## command limit fails the run, named in its result.

const STRATEGIES: Array[String] = ["collective", "private", "mixed"]
const PARAMS: BalanceParams = preload("res://tools/balance_params.tres")
## The wild ranks' three items (ADR 0029), whose purchases the harness counts.
const WILD_ITEMS: Array[String] = ["model_worker", "mass_line", "industrialization"]

var result: BalanceResult = BalanceResult.new()
## Weights Expert villagers search with in place of the game's, from sampling(), or
## null for the game's own (ADR 0027).
var search_weights: BotWeights = null

var _strategy: BalanceStrategy
var _params: BalanceParams
var _stake: int
var _errors: BalanceErrors
var _hard: BotConfig
var _controller: RunController
var _commands: int = 0
## The bids of the bidding under way, as seat and claim.
var _bids: Array[Vector2i] = []
## The rank counts of the last hand dealt to the player, for a rank pick.
var _last_hand: PackedByteArray = PackedByteArray()
var _fresh_deal: bool = false
var _market_bought: int = 0
var _rerolled: bool = false
var _directive_bought: bool = false


## errors, when given, is the logger whose count for this thread fails the run.
func _init(
	strategy: BalanceStrategy,
	stake: int = 0,
	errors: BalanceErrors = null,
	numbers: BalanceParams = PARAMS
) -> void:
	_strategy = strategy
	_params = numbers
	_stake = stake
	_errors = errors
	_last_hand.resize(Ranks.COUNT)


## A strategy by its name, or null for one the harness does not know.
static func strategy_named(
	strategy_name: String, numbers: BalanceParams = PARAMS
) -> BalanceStrategy:
	match strategy_name:
		"collective":
			return BalanceCollective.new(numbers)
		"private":
			return BalancePrivate.new(numbers)
		"mixed":
			return BalanceMixed.new(numbers)
	return null


## A copy of the bots' weights whose Expert samples that many deals, and needs no more
## of them finished than that; the shared Resource is left as it is.
static func sampling(samples: int) -> BotWeights:
	var weights: BotWeights = BotConfig.DEFAULT_WEIGHTS.duplicate()
	weights.expert_samples = samples
	weights.expert_min_samples = mini(weights.expert_min_samples, samples)
	return weights


## The controller a run plays through: the app's, but with no deadline on a search, and
## with search_weights when set.
func new_controller() -> RunController:
	var controller: RunController = RunController.new()
	controller.live_search = false
	controller.search_weights = search_weights
	return controller


## The request the harness starts every run with.
func request(seed_value: int) -> RunRequest:
	var asked: RunRequest = RunRequest.new(RunRequest.FULL, seed_value, _params.start_time)
	asked.household = _params.household
	asked.stake = _stake
	asked.writes_profile = false
	asked.all_open = true
	return asked


func play(seed_value: int) -> BalanceResult:
	var began: int = Time.get_ticks_usec()
	result.seed_value = seed_value
	result.strategy = _strategy.name()
	result.stake = _stake
	_hard = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.HARD, seed_value)
	if _errors != null:
		_errors.take()
	_controller = new_controller()
	_controller.event_emitted.connect(_on_event)
	if not _controller.start(request(seed_value)):
		_fail("the run did not start")
	while not result.failed() and _controller.awaiting() != RunController.AWAIT_RUN_OVER:
		if _commands >= _params.max_commands:
			_fail("no end within %d commands" % _params.max_commands)
			break
		_step()
	if _controller.has_run():
		_finish()
	if _errors != null and not result.failed():
		var logged: String = _errors.take()
		if not logged.is_empty():
			_fail(logged)
	_controller.free()
	_controller = null
	result.seconds = (Time.get_ticks_usec() - began) / 1_000_000.0
	return result


func _finish() -> void:
	# The controller keeps the loop's bot count to itself; the tests read it the same way.
	var loop: RunLoop = _controller.get("_loop")
	var refused: int = loop.refused_bot_actions
	if refused > 0:
		_fail("%d bot actions refused" % refused)
	result.finish(_controller.state_copy())


func _step() -> void:
	_remember_hand()
	match _controller.awaiting():
		RunController.AWAIT_BID:
			_bid()
		RunController.AWAIT_SWAP:
			_swap()
		RunController.AWAIT_OPENING:
			if not _use_campaign():
				_send("begin_round", _controller.begin_round())
		RunController.AWAIT_PLAY:
			if not _use_campaign():
				_play()
		RunController.AWAIT_NEED:
			_need()
		RunController.AWAIT_SET_OVER:
			_market_bought = 0
			_rerolled = false
			_directive_bought = false
			_send("finish_set", _controller.finish_set())
		RunController.AWAIT_STORE:
			_shop()
		RunController.AWAIT_REEDUCATION:
			_send("leave_reeducation", _controller.leave_reeducation())
		var other:
			_fail("the run awaits %d, which no command answers" % other)


func _send(command: String, reason: int) -> void:
	_commands += 1
	if reason != RunController.OK:
		_fail("%s refused (%d) at Year %d" % [command, reason, _year()])


func _fail(why: String) -> void:
	if result.failure.is_empty():
		result.failure = why


func _year() -> int:
	return _controller.state_copy().year if _controller.has_run() else 0


## The hand as first seen after a deal, for the rank a Cadre purchase picks.
func _remember_hand() -> void:
	if not _fresh_deal:
		return
	var cards: Array[CardInstance] = _controller.player_cards()
	if cards.is_empty():
		return
	_last_hand = BalanceCards.counts(cards)
	_fresh_deal = false


func _bid() -> void:
	var bidding: Bidding = _bidding()
	var is_grab: bool = _controller.bid_holder() != Seats.NONE
	var is_last: bool = bidding != null and bidding.is_last_to_act()
	var bot_calls: bool = Bot.decide_bid(
		BalanceCards.counts(_controller.player_cards()),
		false,
		is_last,
		_controller.player_table(),
		_hard,
		BotBudget.unlimited()
	)
	var claim: bool = _strategy.bid(is_grab, bot_calls)
	if claim:
		if is_grab:
			result.grabs += 1
		else:
			result.calls += 1
	_send("bid", _controller.bid(claim))


## The bidding under way, rebuilt from its bids since the deal, or null when they do not
## lead to the player's turn.
func _bidding() -> Bidding:
	var first: int = RunLoop.PLAYER if _bids.is_empty() else _bids[0].x
	var bidding: Bidding = Bidding.new(first)
	for bid: Vector2i in _bids:
		bidding.act(bid.x, bid.y == 1)
	return bidding if bidding.seat_to_act() == RunLoop.PLAYER else null


func _swap() -> void:
	var hand_ids: Array[int] = []
	var plot_ids: Array[int] = []
	if _strategy.swaps():
		var plot: Array[CardInstance] = _controller.state_copy().inventory.plot
		var chosen: Array[Array] = BalanceStrategy.best_swap(
			_controller.player_cards(),
			plot,
			_controller.swap_limit(),
			_controller.player_table().rank_map
		)
		hand_ids.assign(chosen[0])
		plot_ids.assign(chosen[1])
	result.swapped_cards += hand_ids.size()
	_send("swap", _controller.swap(hand_ids, plot_ids))


func _play() -> void:
	var legal: Array[Pattern] = _controller.legal_moves()
	var play: BotPlay = Bot.decide_play(
		_controller.seat_view(), legal, _controller.player_table(), _hard, BotBudget.unlimited()
	)
	if play.is_pass() and not _controller.pass_refusal().is_empty():
		# Night Shift refuses the pass: the first legal play goes instead (ADR 0023).
		_send("play", _controller.play(_controller.card_ids_for(legal[0])))
	elif play.is_pass():
		_send("pass", _controller.pass_turn())
	else:
		# Under a wild rank the play is sent as the reading the bot chose (ADR 0029).
		var reading: Pattern = null if _controller.wild_ranks().is_empty() else play.pattern
		_send("play", _controller.play(_controller.card_ids_for(play.pattern), reading))


func _need() -> void:
	var faces: int = roundi(_controller.audit_chance() * RunPools.AUDIT.die_sides)
	var claim: int = _strategy.need(_controller.base_need(), RunStarter.DEMO_RUN.need_cap, faces)
	result.max_need = maxi(result.max_need, claim)
	_send("declare_need", _controller.declare_need(claim))


## Uses the first held Campaign the strategy uses and the run allows now. Returns true
## when it sent one.
func _use_campaign() -> bool:
	var held: Array[String] = _controller.held_campaigns()
	for slot: int in held.size():
		if not _strategy.uses_campaign(held[slot]):
			continue
		if not BalanceWave.helps(held[slot], _controller.state_copy(), _params):
			continue
		if _controller.campaign_reason(slot, [], false) != RunController.CAMPAIGN_OK:
			continue
		var cards: Array[int] = _campaign_cards(slot, held[slot])
		if _controller.campaign_reason(slot, cards, true) != RunController.CAMPAIGN_OK:
			continue
		_send("campaign", _controller.campaign(slot, cards))
		return true
	return false


## The cards a Campaign is used on: as many as it takes, the lowest for one that gives
## them away and the highest otherwise, each one the run accepts.
func _campaign_cards(slot: int, campaign_id: String) -> Array[int]:
	var chosen: Array[int] = []
	var most: int = _controller.campaign_cards(campaign_id).y
	if most == 0:
		return chosen
	var giving: bool = _params.giving_campaigns.has(campaign_id)
	var rank_map: PackedByteArray = _controller.player_table().rank_map
	for card: CardInstance in BalanceCards.sorted(_controller.player_cards(), rank_map, giving):
		if chosen.size() >= most:
			break
		var tried: Array[int] = chosen.duplicate()
		tried.append(card.id())
		var reason: int = _controller.campaign_reason(slot, tried, true)
		if reason == RunController.CAMPAIGN_OK or reason == CampaignEffect.Reason.CARD_COUNT:
			chosen = tried
	return chosen


func _shop() -> void:
	var state: RunState = _controller.state_copy()
	var use: String = _shop_step(state)
	if use.is_empty():
		result.ledger.left_store(state.coupons)
		_send("leave_store", _controller.leave_store())
	else:
		result.ledger.shop_step(use, state.coupons, _controller.state_copy().coupons)


## Takes one step at the shops and names what for, as BalanceLedger does, or returns ""
## when the strategy is done there.
func _shop_step(state: RunState) -> String:
	var opened: EnvelopeShelf = _controller.opened_envelope()
	if opened != null:
		_send("envelope_pick", _controller.envelope_pick(BalanceShop.envelope_pick(opened)))
		return "envelopes"
	if _use_campaign():
		return "campaigns"
	var visit: BalanceVisit = BalanceShop.visit(_controller, state)
	visit.market_bought = _market_bought
	visit.rerolled = _rerolled
	visit.directive_bought = _directive_bought
	var offer: BalanceOffer = _strategy.purchase(visit)
	if offer != null:
		_bought(offer, state)
		var rank: int = BalanceCards.most_held(_rank_counts(state))
		if not offer.market or not _controller.needs_rank(offer.item_id):
			rank = Ranks.INVALID
		_send("buy", BalanceShop.buy(_controller, offer, rank))
		return BalanceLedger.category(offer)
	if _strategy.rerolls(visit):
		_rerolled = true
		result.rerolls += 1
		_send("market_reroll", _controller.market_reroll())
		return "rerolls"
	return ""


func _bought(offer: BalanceOffer, state: RunState) -> void:
	var item_id: String = offer.item_id
	if offer.kind == BalanceOffer.Kind.REFORM:
		item_id = _controller.reform_shelf().stock()[offer.slot]
	elif offer.kind == BalanceOffer.Kind.CAMPAIGN:
		item_id = _controller.campaign_shelf(offer.market).stock()[offer.slot]
	if WILD_ITEMS.has(item_id):
		result.wild_buys[item_id] = result.wild_buys.get(item_id, 0) + 1
	if BalanceWave.ITEMS.has(item_id):
		result.wave_buys[item_id] = result.wave_buys.get(item_id, 0) + 1
	if offer.kind == BalanceOffer.Kind.DIRECTIVE:
		_directive_bought = true
		result.directive_buys += 1
		return
	if not offer.market:
		result.store_buys += 1
		var left: int = state.coupons - offer.price
		result.store_floor = left if result.store_floor < 0 else mini(result.store_floor, left)
		return
	result.market_buys += 1
	_market_bought += 1
	result.market_buys_per_visit = maxi(result.market_buys_per_visit, _market_bought)
	if state.resentment >= _params.resentment_limit:
		result.market_buys_over_limit += 1


## The ranks the player holds: the last hand dealt and the plot.
func _rank_counts(state: RunState) -> PackedByteArray:
	var counts: PackedByteArray = BalanceCards.counts(state.inventory.plot)
	for rank: int in Ranks.COUNT:
		counts[rank] += _last_hand[rank]
	return counts


func _on_event(event: RunEvent) -> void:
	result.ledger.heard(event, _controller)
	match event.type:
		RunEvent.Type.DEALT:
			_bids.clear()
			_fresh_deal = true
		RunEvent.Type.BID:
			_bids.append(Vector2i(event.seat, event.value))
		RunEvent.Type.LANDLORD_CHOSEN:
			if event.seat == RunLoop.PLAYER:
				result.landlord_rounds += 1
		RunEvent.Type.SET_ENDED:
			result.quotas_played += 1
			result.quotas_met += event.value
		RunEvent.Type.STARVED:
			result.starved += 1
		RunEvent.Type.CAMPAIGN_USED:
			result.campaigns_used += 1
			if event.text == WILD_ITEMS[0]:
				result.workers_used += 1
			if BalanceWave.ITEMS.has(event.text):
				result.wave_uses[event.text] = result.wave_uses.get(event.text, 0) + 1
		RunEvent.Type.WILD_RANKS:
			result.wild_draws += 1
		RunEvent.Type.RESENTMENT:
			if event.text in [Resentment.PRIVATE_PURCHASE, Resentment.PRIVATE_CADRE]:
				result.market_resentment += event.value
