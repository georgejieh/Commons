class_name CardName
extends RefCounted
## How text names a card: "9 of Spades", or a joker by its rank alone.

## Suit names in suit order: spade, heart, club, diamond.
const SUIT_KEYS: Array[String] = ["suit.spades", "suit.hearts", "suit.clubs", "suit.diamonds"]


## A card's name, by the rank it was printed with.
static func of(card: CardInstance) -> String:
	return of_rank(card.base_rank(), card.suit())


## The name of the card of rank and suit.
static func of_rank(rank: int, suit: int) -> String:
	var rank_name: String = TranslationServer.translate(Ranks.label_key(rank))
	if rank >= Ranks.SMALL_JOKER:
		return rank_name
	var suit_name: String = TranslationServer.translate(SUIT_KEYS[suit])
	return TranslationServer.translate("card.name").format({"rank": rank_name, "suit": suit_name})
