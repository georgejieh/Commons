class_name TournamentLog
extends RefCounted
## Writes one game as a line of JSON. docs/TOURNAMENT_LOG.md describes the format.

const VERSION: int = 1
const SYMBOLS: String = "3456789TJQKA2XD"


static func line(
	game_seed: int, deal: DealResult, names: Array[String], result: SelfPlayResult
) -> String:
	var hands: Array[String] = []
	for hand: Hand in deal.hands:
		hands.append(_text(hand.counts()))
	var plays: Array[Array] = []
	for play: PublicPlay in result.history:
		plays.append([play.seat, _text(play.counts)])
	var kitty: PackedByteArray = PackedByteArray()
	kitty.resize(Ranks.COUNT)
	for card: CardInstance in deal.kitty:
		kitty[card.base_rank()] += 1
	var record: Dictionary[String, Variant] = {
		"version": VERSION,
		"seed": game_seed,
		"seats": names,
		"landlord": result.landlord,
		"hands": hands,
		"kitty": _text(kitty),
		"plays": plays,
		"winner": result.winner,
	}
	return JSON.stringify(record)


static func _text(counts: PackedByteArray) -> String:
	var text: String = ""
	for rank: int in counts.size():
		text += SYMBOLS[rank].repeat(counts[rank])
	return text
