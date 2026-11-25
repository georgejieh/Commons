class_name EnvelopeContents
extends RefCounted
## What an envelope holds, and what keeping each kind of item does (ADR 0021). Each place
## is drawn by weight from the kinds that still have something new to show, then an item
## of that kind evenly from those not already in the envelope, so no item shows twice and
## an envelope with less to draw shows fewer. Keeping a Directive issues it as the counter
## does; a Campaign joins the held ones; a plot card is made under a new plot ID, marked,
## and put in the plot; a deck card takes the place of the deck card the player names
## (ADR 0042). A card is drawn from the 52 a plain deck holds but its jokers, by rank then
## suit, and a deck card only of a rank the deck has room for.

## The ranks a card in an envelope may have: 3 to 2, never a joker.
const CARD_RANKS: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]


## Up to count items for one envelope, drawn on stream from what the counter offers: its
## Directives below the top level and its Campaign pool.
static func draw(
	envelope: EnvelopeDef,
	count: int,
	state: RunState,
	run: RunParams,
	directives: Array[DirectiveDef],
	campaigns: Array[CampaignDef],
	stream: RandomStream
) -> Array[EnvelopeItem]:
	var open: Array[DirectiveDef] = directives.filter(
		func(directive: DirectiveDef) -> bool: return not is_maxed(state, directive)
	)
	var drawn: Array[EnvelopeItem] = []
	var room: Array[int] = DeckExchange.open_ranks(state, run, CARD_RANKS)
	while drawn.size() < count:
		var kinds: Array[int] = []
		var total: int = 0
		for index: int in mini(envelope.contents.size(), envelope.weights.size()):
			if _candidates(envelope.contents[index], drawn, open, campaigns, room).is_empty():
				continue
			kinds.append(index)
			total += maxi(envelope.weights[index], 0)
		if total <= 0:
			break
		var roll: int = stream.next_int(0, total - 1)
		var kind: EnvelopeDef.Content = envelope.contents[kinds[-1]]
		for index: int in kinds:
			roll -= maxi(envelope.weights[index], 0)
			if roll < 0:
				kind = envelope.contents[index]
				break
		var candidates: Array[EnvelopeItem] = _candidates(kind, drawn, open, campaigns, room)
		drawn.append(candidates[stream.next_int(0, candidates.size() - 1)])
	return drawn


## True when the envelope has anything at all to show, for the counter's offer.
static func has_any(
	envelope: EnvelopeDef,
	state: RunState,
	run: RunParams,
	directives: Array[DirectiveDef],
	campaigns: Array[CampaignDef]
) -> bool:
	var open: Array[DirectiveDef] = directives.filter(
		func(directive: DirectiveDef) -> bool: return not is_maxed(state, directive)
	)
	var none: Array[EnvelopeItem] = []
	var room: Array[int] = DeckExchange.open_ranks(state, run, CARD_RANKS)
	for kind: EnvelopeDef.Content in envelope.contents:
		if not _candidates(kind, none, open, campaigns, room).is_empty():
			return true
	return false


## Why the item cannot be kept now, or OK: a Campaign needs a free place among the held
## ones, a plot card room in the plot, and a deck card room for its rank in the deck and,
## once it is named, a deck card that may leave.
static func check(
	item: EnvelopeItem, state: RunState, run: RunParams, out: int = Deck.NO_SLOT
) -> RunShop.Reason:
	if item.is_deck_card():
		var room: RunShop.Reason = DeckExchange.check_in(state, run, item.rank)
		if room != RunShop.Reason.OK or out == Deck.NO_SLOT:
			return room
		return DeckExchange.check_out(state, out)
	match item.content:
		EnvelopeDef.Content.CAMPAIGN:
			if state.inventory.consumables.size() >= RunReforms.campaign_slots(state):
				return RunShop.Reason.CAMPAIGNS_FULL
		EnvelopeDef.Content.STAMPED_CARD, EnvelopeDef.Content.MODEL_CARD:
			if state.inventory.plot.size() >= PlotSwap.capacity(state, run):
				return RunShop.Reason.PLOT_FULL
	return RunShop.Reason.OK


## Keeps the item for the seat: issued, held, put in the plot with its mark, or put in the
## deck in place of the card in out, without which a deck card is refused.
static func take(
	item: EnvelopeItem,
	state: RunState,
	run: RunParams,
	seat: int,
	directives: Array[DirectiveDef],
	out: int = Deck.NO_SLOT
) -> RunShop.Reason:
	var reason: RunShop.Reason = check(item, state, run, out)
	if reason == RunShop.Reason.OK and item.is_deck_card() and out == Deck.NO_SLOT:
		reason = RunShop.Reason.NO_SUCH_CARD
	if reason != RunShop.Reason.OK:
		return reason
	if item.is_deck_card():
		DeckExchange.apply(state, out, item.rank, item.suit, item.enhancement)
		return RunShop.Reason.OK
	match item.content:
		EnvelopeDef.Content.DIRECTIVE:
			for directive: DirectiveDef in directives:
				if directive.id == item.item_id:
					RunShop.issue(state, directive)
		EnvelopeDef.Content.CAMPAIGN:
			state.inventory.consumables.append(item.item_id)
		_:
			var card: CardInstance = CardInstance.new(
				state.take_plot_id(), item.rank, item.suit, CardInstance.Origin.PLOT
			)
			if item.content == EnvelopeDef.Content.STAMPED_CARD:
				CardMarks.stamp(state, card, seat)
			else:
				CardMarks.enhance(state, card, CardInstance.MODEL)
			PlotSwap.store(state, card, run)
	return RunShop.Reason.OK


## True when every hand type the Directive raises is at the top level.
static func is_maxed(state: RunState, directive: DirectiveDef) -> bool:
	for type: int in directive.hand_types:
		if not state.hand_levels.is_max(type as Pattern.Type):
			return false
	return true


## Every item of a kind not already drawn, in a fixed order; a deck card only of a rank
## in room.
static func _candidates(
	kind: EnvelopeDef.Content,
	drawn: Array[EnvelopeItem],
	directives: Array[DirectiveDef],
	campaigns: Array[CampaignDef],
	room: Array[int]
) -> Array[EnvelopeItem]:
	var all: Array[EnvelopeItem] = []
	match kind:
		EnvelopeDef.Content.DIRECTIVE:
			for directive: DirectiveDef in directives:
				all.append(EnvelopeItem.new(kind, directive.id))
		EnvelopeDef.Content.CAMPAIGN:
			for campaign: CampaignDef in campaigns:
				all.append(EnvelopeItem.new(kind, campaign.id))
		EnvelopeDef.Content.DECK_CARD:
			_add_cards(all, kind, room, [CardInstance.NO_ID])
		EnvelopeDef.Content.MARKED_DECK_CARD:
			_add_cards(all, kind, room, CardInstance.ENHANCEMENTS)
		_:
			_add_cards(all, kind, CARD_RANKS, [CardInstance.NO_ID])
	return all.filter(
		func(item: EnvelopeItem) -> bool:
			return not drawn.any(func(taken: EnvelopeItem) -> bool: return taken.same_as(item))
	)


## A card of each rank in ranks in each suit, with each of marks, in that order.
static func _add_cards(
	all: Array[EnvelopeItem], kind: EnvelopeDef.Content, ranks: Array[int], marks: Array[String]
) -> void:
	for rank: int in ranks:
		for suit: int in Deck.SUITS:
			for mark: String in marks:
				all.append(EnvelopeItem.new(kind, "", rank, suit, mark))
