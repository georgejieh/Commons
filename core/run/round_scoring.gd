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
## The Grain each seat's last play scored this round, for Collective Farm (ADR 0021).
var _seat_grain: PackedFloat64Array = PackedFloat64Array()
## The Grain, Rate and Zeal of the play scored or previewed last.
var _last_grain: float = 0.0
var _last_rate: float = 0.0
var _last_zeal: float = 0.0


func _init(levels: HandLevels, stack: ModifierStack) -> void:
	_levels = levels
	_stack = stack


func start(landlord: int) -> void:
	_landlord = landlord
	_scores = PackedFloat64Array()
	_scores.resize(Seats.COUNT)
	_plays = PackedInt32Array()
	_plays.resize(Seats.COUNT)
	_seat_grain = PackedFloat64Array()
	_seat_grain.resize(Seats.COUNT)


## Scores a PLAYED event and adds it to the seat's round score. cards_left is the seat's
## hand size once the play is made.
func score(event: RoundEvent, cards_left: int = -1) -> float:
	var total: float = _score_cards(event.cards, event.pattern, event.seat, cards_left)
	_scores[event.seat] += total
	_plays[event.seat] += 1
	_seat_grain[event.seat] = _last_grain
	return total


func last_grain() -> float:
	return _last_grain


func last_rate() -> float:
	return _last_rate


func last_zeal() -> float:
	return _last_zeal


func scores() -> PackedFloat64Array:
	return _scores


## How the seat's cards would read and score if played now.
func preview(round_state: RoundState, seat: int, card_ids: Array[int]) -> PlayPreview:
	var reading: PlayReading = round_state.read_play(seat, card_ids)
	if reading.pattern == null:
		return PlayPreview.new(reading, 0.0)
	var left: int = round_state.remaining()[seat] - reading.cards.size()
	var score: float = _score_cards(reading.cards, reading.pattern, seat, left)
	var preview: PlayPreview = PlayPreview.new(reading, score, _last_grain, _last_rate, _last_zeal)
	var copies: Array[CardInstance] = []
	for card: CardInstance in reading.cards:
		copies.append(card.snapshot())
	reading.cards = copies
	return preview


func _score_cards(
	cards: Array[CardInstance], pattern: Pattern, seat: int, cards_left: int
) -> float:
	var breakdown: ScoreBreakdown = Scorer.score_play(
		cards,
		pattern,
		_levels.level_of(pattern.type),
		seat,
		seat == _landlord,
		_stack,
		Scorer.DEFAULT_PARAMS,
		_plays[seat],
		PlayFacts.new(_landlord, cards_left, _plays, _seat_grain)
	)
	_last_grain = breakdown.grain
	_last_rate = breakdown.rate
	_last_zeal = breakdown.zeal
	return breakdown.total
