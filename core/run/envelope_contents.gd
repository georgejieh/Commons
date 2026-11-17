class_name EnvelopeContents
extends RefCounted
## What an envelope holds, and what keeping each kind of item does (ADR 0021). Each place
## is drawn by weight from the kinds that still have something new to show, then an item
## of that kind evenly from those not already in the envelope, so no item shows twice and
## an envelope with less to draw shows fewer. Keeping a Directive issues it as the counter
## does; a Campaign joins the held ones; a plot card is made under a new plot ID, marked,
## and put in the plot.

## The 52 cards a plot card is drawn from: every deck card but the jokers.
const CARDS: int = Deck.SMALL_JOKER_ID


## Up to count items for one envelope, drawn on stream from what the counter offers: its
## Directives below the top level and its Campaign pool.
static func draw(
	envelope: EnvelopeDef,
	count: int,
	state: RunState,
	directives: Array[DirectiveDef],
	campaigns: Array[CampaignDef],
	stream: RandomStream
) -> Array[EnvelopeItem]:
	var open: Array[DirectiveDef] = directives.filter(
		func(directive: DirectiveDef) -> bool: return not is_maxed(state, directive)
	)
	var drawn: Array[EnvelopeItem] = []
	while drawn.size() < count:
		var kinds: Array[int] = []
		var total: int = 0
		for index: int in mini(envelope.contents.size(), envelope.weights.size()):
			if _candidates(envelope.contents[index], drawn, open, campaigns).is_empty():
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
		var candidates: Array[EnvelopeItem] = _candidates(kind, drawn, open, campaigns)
		drawn.append(candidates[stream.next_int(0, candidates.size() - 1)])
	return drawn


## True when the envelope has anything at all to show, for the counter's offer.
static func has_any(
	envelope: EnvelopeDef,
	state: RunState,
	directives: Array[DirectiveDef],
	campaigns: Array[CampaignDef]
) -> bool:
	var open: Array[DirectiveDef] = directives.filter(
		func(directive: DirectiveDef) -> bool: return not is_maxed(state, directive)
	)
	var none: Array[EnvelopeItem] = []
	for kind: EnvelopeDef.Content in envelope.contents:
		if not _candidates(kind, none, open, campaigns).is_empty():
			return true
	return false


## Why the item cannot be kept now, or OK: a Campaign needs a free place among the held
## ones, a plot card room in the plot.
static func check(item: EnvelopeItem, state: RunState, run: RunParams) -> RunShop.Reason:
	match item.content:
		EnvelopeDef.Content.CAMPAIGN:
			if state.inventory.consumables.size() >= RunReforms.campaign_slots(state):
				return RunShop.Reason.CAMPAIGNS_FULL
		EnvelopeDef.Content.STAMPED_CARD, EnvelopeDef.Content.MODEL_CARD:
			if state.inventory.plot.size() >= PlotSwap.capacity(state, run):
				return RunShop.Reason.PLOT_FULL
	return RunShop.Reason.OK


## Keeps the item for the seat: issued, held, or put in the plot with its mark.
static func take(
	item: EnvelopeItem, state: RunState, run: RunParams, seat: int, directives: Array[DirectiveDef]
) -> RunShop.Reason:
	var reason: RunShop.Reason = check(item, state, run)
	if reason != RunShop.Reason.OK:
		return reason
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
				CardMarks.make_model(state, card)
			PlotSwap.store(state, card, run)
	return RunShop.Reason.OK


## True when every hand type the Directive raises is at the top level.
static func is_maxed(state: RunState, directive: DirectiveDef) -> bool:
	for type: int in directive.hand_types:
		if not state.hand_levels.is_max(type as Pattern.Type):
			return false
	return true


## Every item of a kind not already drawn, in a fixed order.
static func _candidates(
	kind: EnvelopeDef.Content,
	drawn: Array[EnvelopeItem],
	directives: Array[DirectiveDef],
	campaigns: Array[CampaignDef]
) -> Array[EnvelopeItem]:
	var all: Array[EnvelopeItem] = []
	match kind:
		EnvelopeDef.Content.DIRECTIVE:
			for directive: DirectiveDef in directives:
				all.append(EnvelopeItem.new(kind, directive.id))
		EnvelopeDef.Content.CAMPAIGN:
			for campaign: CampaignDef in campaigns:
				all.append(EnvelopeItem.new(kind, campaign.id))
		_:
			for deck_id: int in CARDS:
				all.append(EnvelopeItem.new(kind, "", Deck.rank_of(deck_id), Deck.suit_of(deck_id)))
	return all.filter(
		func(item: EnvelopeItem) -> bool:
			return not drawn.any(func(taken: EnvelopeItem) -> bool: return taken.same_as(item))
	)
