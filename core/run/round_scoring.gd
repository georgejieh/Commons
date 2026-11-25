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
var _last_stamps_resented: bool = true
var _last_surplus: Array[int] = []
## What changed the last real play's score, in order. A preview keeps none.
var _last_steps: Array[ScoreStep] = []
## The run's Year in play, for the hooks that grow with it (ADR 0032).
var _year: int = 0


func _init(levels: HandLevels, stack: ModifierStack) -> void:
	_levels = levels
	_stack = stack


func start(landlord: int, year: int = 0) -> void:
	_landlord = landlord
	_year = year
	_scores = PackedFloat64Array()
	_scores.resize(Seats.COUNT)
	_plays = PackedInt32Array()
	_plays.resize(Seats.COUNT)
	_seat_grain = PackedFloat64Array()
	_seat_grain.resize(Seats.COUNT)


## Scores a PLAYED event and adds it to the seat's round score. cards_left is the seat's
## hand size once the play is made.
func score(event: RoundEvent, cards_left: int = -1) -> float:
	var total: float = _score_cards(event.cards, event.pattern, event.seat, cards_left, true)
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


## What changed the last play scored, one step at a time, for the table to act out.
func last_steps() -> Array[ScoreStep]:
	return _last_steps


## False when a hook waived the Resentment the last play's stamped cards add (ADR 0032).
func last_stamps_resented() -> bool:
	return _last_stamps_resented


## The scored Surplus cards of the last play, which pay the player (ADR 0041).
func last_surplus_cards() -> Array[int]:
	return _last_surplus


func scores() -> PackedFloat64Array:
	return _scores


## How the seat's cards would read and score if played now, as wanted when it names one
## of their readings.
func preview(
	round_state: RoundState, seat: int, card_ids: Array[int], wanted: Pattern = null
) -> PlayPreview:
	var reading: PlayReading = round_state.read_play(seat, card_ids, wanted)
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
	cards: Array[CardInstance], pattern: Pattern, seat: int, cards_left: int, record: bool = false
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
		PlayFacts.new(_landlord, cards_left, _plays, _seat_grain, _year),
		record
	)
	_last_grain = breakdown.grain
	_last_rate = breakdown.rate
	_last_zeal = breakdown.zeal
	_last_stamps_resented = breakdown.stamps_resented
	_last_surplus = breakdown.surplus_cards
	_last_steps = breakdown.trail
	return breakdown.total
