class_name SwapFit
extends RefCounted
## How the plot swap's board stands (ADR 0038): which cards are in each of its three
## places as the trade stands, and where each place starts and how far apart its cards
## lie, fitted to the board's width. The hand keeps at least its least step, as close as
## the table's own fan; the set-aside cards and the plot close up first to make room.

const CARD: Vector2 = Vector2(120, 168)
## The room between places.
const GAP: float = 40.0
## The hand's step at most, as wide as the table's fan, and at least.
const HAND_STEP_MAX: float = 64.0
const HAND_STEP_LEAST: float = 46.0
## The steps tried for the set-aside cards and the plot, widest first.
const SIDE_STEPS: Array[float] = [132.0, 104.0, 84.0, 64.0]
const TAG_SIZE: int = 20
## An empty place is a faint sheet of the same paper.
const PLACE_ALPHA: float = 0.35


## The three places' cards as they stand: the hand as it will be played, sorted, the
## cards set aside in the order they were traded, and the plot cards still in the plot.
static func places(
	hand: Array[CardInstance], plot: Array[CardInstance], trade: PlotTrade, sort: Callable
) -> Array[Array]:
	var played: Array[CardInstance] = []
	var out: Array[CardInstance] = []
	var kept: Array[CardInstance] = []
	for card: CardInstance in hand:
		if not trade.is_traded(card.id()):
			played.append(card)
	for card: CardInstance in plot:
		if trade.is_traded(card.id()):
			played.append(card)
		else:
			kept.append(card)
	for card_id: int in trade.hand_ids:
		for card: CardInstance in hand:
			if card.id() == card_id:
				out.append(card)
	var sorted: Array[CardInstance] = sort.call(played)
	return [sorted, out, kept]


## Each place's left edge and step: the hand from the left, the plot at the right and the
## set-aside cards beside it. counts and least_widths are per place, in that order; a
## place is never narrower than its name.
static func fit(width: float, counts: Array[int], least_widths: Array[float]) -> Array[Vector2]:
	var side: float = SIDE_STEPS[-1]
	var hand_step: float = HAND_STEP_MAX
	for step: float in SIDE_STEPS:
		side = step
		var room: float = width - span(counts[1], step, least_widths[1])
		room -= span(counts[2], step, least_widths[2]) + GAP * 2.0
		hand_step = (room - CARD.x) / maxf(1.0, counts[0] - 1)
		if hand_step >= HAND_STEP_LEAST:
			break
	hand_step = minf(hand_step, HAND_STEP_MAX)
	var plot_x: float = width - span(counts[2], side, least_widths[2])
	var out_x: float = plot_x - GAP - span(counts[1], side, least_widths[1])
	return [Vector2(0.0, hand_step), Vector2(out_x, side), Vector2(plot_x, side)]


static func span(count: int, step: float, least: float) -> float:
	return maxf(least, CARD.x + (count - 1) * step)


## The width the three places need at their least steps.
static func needed_width(counts: Array[int]) -> float:
	var least: float = CARD.x + (counts[0] - 1) * HAND_STEP_LEAST
	for place: int in [1, 2]:
		least += CARD.x + (counts[place] - 1) * SIDE_STEPS[-1]
	return least + GAP * 2.0


## A pair's number, on a scrap of the sheet's paper.
static func tag(number: int) -> Label:
	var made: Label = ScreenKit.label(str(number), TAG_SIZE)
	made.autowrap_mode = TextServer.AUTOWRAP_OFF
	made.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	made.add_theme_stylebox_override("normal", ScreenKit.paper_style(4))
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	made.z_index = ScreenKit.LAYER_OVER
	return made


## Where a card stands when it is not there.
static func empty_place() -> Control:
	var place: PanelContainer = PanelContainer.new()
	place.add_theme_stylebox_override("panel", ScreenKit.paper_style(0))
	place.modulate.a = PLACE_ALPHA
	place.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place.size = CARD
	return place
