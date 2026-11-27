class_name DeckFit
extends RefCounted
## How the deck sheet lays out its cards (ADR 0041): one group a rank, its cards fanned
## left to right as the hand fans them, so each card's left edge, where its marks are,
## shows; the private plot's cards are a last group. The groups stand in rows, as many to
## a row as gives the cards the largest scale that fits the room, never above full size.
## Below the least scale the cards keep it and the sheet scrolls.

## A card's size at full scale, the same as on the swap board.
const CARD: Vector2 = SwapFit.CARD
## The step between a group's cards at full size, as wide as shows a card's marks.
const STEP: float = 46.0
## The most cards a group lays out at the full step; a group with more closes up to fit.
const GROUP_CARDS: int = 4
## The gap between groups in a row, at full scale and in pixels.
const GAP: float = 26.0
## The gap between rows of groups, in pixels.
const ROW_GAP: float = 14.0
## The numbers of groups to a row the layout tries, most first, keeping the one that gives the
## cards the largest scale.
const COLUMNS: Array[int] = [8, 7, 6, 5, 4]
## The least scale the cards are drawn at; below it they keep it and the sheet scrolls.
const LEAST_SCALE: float = 0.6

## The scale cards are drawn at.
var scale: float = 1.0
## How many groups stand in a row.
var columns: int = 1
## Where each group's first card sits, in the room's pixels.
var places: Array[Vector2] = []
## The step between each group's cards, in pixels, closed up for a group with more than
## GROUP_CARDS.
var steps: Array[float] = []
## The room the whole layout takes.
var size: Vector2 = Vector2.ZERO


## Lays out groups of counts cards in room, each under a name label name_height tall.
static func fit(counts: Array[int], room: Vector2, name_height: float) -> DeckFit:
	var best: DeckFit = null
	for count: int in COLUMNS:
		var made: DeckFit = _at(counts, room, name_height, count)
		if best == null or made.scale > best.scale:
			best = made
	return best


## The width of one group's slot at full size.
static func _slot_width() -> float:
	return CARD.x + (GROUP_CARDS - 1) * STEP


static func _at(counts: Array[int], room: Vector2, name_height: float, across: int) -> DeckFit:
	var made: DeckFit = DeckFit.new()
	made.columns = across
	var rows: int = ceili(counts.size() / float(across))
	var wide: float = (room.x - (across - 1) * GAP) / (across * _slot_width())
	var tall_room: float = room.y - rows * name_height - (rows - 1) * ROW_GAP
	var tall: float = tall_room / (rows * CARD.y)
	made.scale = clampf(minf(wide, tall), minf(LEAST_SCALE, wide), 1.0)
	var slot: Vector2 = Vector2(_slot_width(), CARD.y) * made.scale
	for index: int in counts.size():
		var column: int = index % across
		var row: int = floori(index / float(across))
		var at: Vector2 = Vector2(column * (slot.x + GAP), row * (name_height + slot.y + ROW_GAP))
		made.places.append(at)
		var spread: float = _slot_width() - CARD.x
		var step: float = STEP if counts[index] <= GROUP_CARDS else spread / (counts[index] - 1)
		made.steps.append(step * made.scale)
	var used: int = mini(across, counts.size())
	made.size = Vector2(used * slot.x + (used - 1) * GAP, rows * (name_height + slot.y + ROW_GAP))
	made.size.y -= ROW_GAP
	return made
