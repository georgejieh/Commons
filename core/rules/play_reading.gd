class_name PlayReading
extends RefCounted
## How a seat's chosen cards read against the table, without playing them: the reason a
## play would be refused or OK, the pattern when the cards form one, and the cards.

## OK when the action would be taken, else why the round would refuse it.
var reason: RoundState.Reason
## Null unless the cards form a pattern, which they can while still not beating the play.
var pattern: Pattern
## Why the cards form no pattern, when they don't.
var invalid_reason: Classification.Reason = Classification.Reason.OK
## The cards the action names, as the seat holds them.
var cards: Array[CardInstance] = []
## Every reading of the cards that may be played now, strongest first (ADR 0029). The
## pattern is the first of them unless the action named another.
var readings: Array[Pattern] = []


## How the cards card_ids of seat's hand read against current, the play to beat or null on
## a lead, by the seat's rules and standing on table; to_act is the seat whose turn it is,
## so a play out of turn reads as refused.
static func of(
	hand: Hand,
	seat: int,
	card_ids: Array[int],
	wanted: Pattern,
	current: Pattern,
	table: SeatRules,
	to_act: int
) -> PlayReading:
	var reading: PlayReading = PlayReading.new(RoundState.Reason.OK)
	var seen: Dictionary[int, bool] = {}
	for card_id: int in card_ids:
		var card: CardInstance = hand.find(card_id)
		if seen.has(card_id) or card == null:
			reading.reason = (
				RoundState.Reason.REPEATED_CARD
				if seen.has(card_id)
				else RoundState.Reason.UNKNOWN_CARD
			)
			return reading
		seen[card_id] = true
		reading.cards.append(card)
	var rules: RuleSet = table.rules_for(seat)
	var counts: PackedByteArray = CardSelection.printed_counts(reading.cards)
	# Keys read standings, so plays of seats with different orders compare (ADR 0039).
	var standing: PackedByteArray = table.standing_for(seat)
	var options: Array[Pattern] = Readings.of(counts, rules, standing)
	if options.is_empty():
		reading.invalid_reason = Classifier.classify(counts, rules, standing).reason
		reading.reason = RoundState.Reason.ILLEGAL_PLAY
		return reading
	for option: Pattern in options:
		if current == null or PlayComparator.beats(option, current, rules):
			reading.readings.append(option)
	reading.pattern = options[0] if reading.readings.is_empty() else reading.readings[0]
	if wanted != null:
		reading.pattern = Readings.checked(wanted, counts, rules, standing)
		if reading.pattern == null:
			reading.reason = RoundState.Reason.ILLEGAL_PLAY
			return reading
	if seat != to_act:
		reading.reason = RoundState.Reason.OUT_OF_TURN
	elif current != null and not PlayComparator.beats(reading.pattern, current, rules):
		reading.reason = RoundState.Reason.DOES_NOT_BEAT
	return reading


func _init(why: RoundState.Reason) -> void:
	reason = why
