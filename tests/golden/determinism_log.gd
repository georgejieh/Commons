class_name DeterminismLog
extends RefCounted
## Builds the scripted log the determinism golden test compares. It stands in for the
## real event log until P1B.8: draws from every stream in a fixed order, then deals, per seed.

const SEEDS: PackedInt64Array = [1, 2026, -7, 9007199254740993]
const DRAWS: int = 4


static func build() -> PackedStringArray:
	var lines: PackedStringArray = []
	for run_seed: int in SEEDS:
		var streams: RandomStreams = RandomStreams.new(run_seed)
		lines.append("seed %d" % run_seed)
		for stream_name: String in RandomStreams.NAMES:
			lines.append(_draw_line(streams, stream_name))
		var bias: DealBias = DealBias.new(0, Ranks.ACE, 2.0)
		lines.append(_deal_line(streams, null))
		lines.append(_deal_line(streams, bias))
	return lines


static func _draw_line(streams: RandomStreams, stream_name: String) -> String:
	var values: PackedStringArray = []
	var stream: RandomStream = streams.stream(stream_name)
	for _i: int in DRAWS:
		values.append(str(stream.next_int(0, 53)))
		values.append("%.9f" % stream.next_float())
	return "%s %s" % [stream_name, " ".join(values)]


static func _deal_line(streams: RandomStreams, bias: DealBias) -> String:
	var cards: Array[CardInstance] = []
	for id: int in Deck.generate():
		cards.append(CardInstance.from_deck_id(id))
	var values: PackedStringArray = []
	for card: CardInstance in Dealer.arrange(cards, streams.stream(RandomStreams.DEAL), bias):
		values.append(str(card.id()))
	return "deal %s" % " ".join(values)
