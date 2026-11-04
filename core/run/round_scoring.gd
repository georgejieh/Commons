class_name RoundScoring
extends RefCounted
## Scores one round's plays as they happen, and previews a play without scoring it. A
## preview and the real play go through the same path, so they always agree, and a
## preview changes nothing: hooks learn how many plays came before from the context.

var _levels: HandLevels
var _stack: ModifierStack
var _landlord: int = Seats.NONE
var _scores: PackedFloat64Array = PackedFloat64Array()
var _plays: PackedInt32Array = PackedInt32Array()


func _init(levels: HandLevels, stack: ModifierStack) -> void:
	_levels = levels
	_stack = stack


func start(landlord: int) -> void:
	_landlord = landlord
	_scores = PackedFloat64Array()
	_scores.resize(Seats.COUNT)
	_plays = PackedInt32Array()
	_plays.resize(Seats.COUNT)


## Scores a PLAYED event and adds it to the seat's round score.
func score(event: RoundEvent) -> float:
	var total: float = _score_cards(event.cards, event.pattern, event.seat)
	_scores[event.seat] += total
	_plays[event.seat] += 1
	return total


func scores() -> PackedFloat64Array:
	return _scores


## How the seat's cards would read and score if played now.
func preview(round_state: RoundState, seat: int, card_ids: Array[int]) -> PlayPreview:
	var reading: PlayReading = round_state.read_play(seat, card_ids)
	if reading.pattern == null:
		return PlayPreview.new(reading, 0.0)
	var score: float = _score_cards(reading.cards, reading.pattern, seat)
	var copies: Array[CardInstance] = []
	for card: CardInstance in reading.cards:
		copies.append(card.snapshot())
	reading.cards = copies
	return PlayPreview.new(reading, score)


func _score_cards(cards: Array[CardInstance], pattern: Pattern, seat: int) -> float:
	var breakdown: ScoreBreakdown = Scorer.score_play(
		cards,
		pattern,
		_levels.level_of(pattern.type),
		seat,
		seat == _landlord,
		_stack,
		Scorer.DEFAULT_PARAMS,
		_plays[seat]
	)
	return breakdown.total
