class_name CardArt
extends Resource
## The parts every card face is composed from (P3C.5). Ranks are drawn from the font, so
## no face is baked: changing one part here restyles every card that uses it. Each part
## goes through ArtStages, so it can change with the corruption stage.

## Card stock and border, under every face.
@export var frame: Texture2D
## Suit icons in suit order: spade, heart, club, diamond.
@export var suits: Array[Texture2D] = []
## Court art for the jack, queen and king, shared by every suit.
@export var court: Array[Texture2D] = []
## The small and big joker.
@export var jokers: Array[Texture2D] = []


## The picture in a card's middle: court or joker art, or else its suit icon.
func picture(rank: int, suit: int) -> Texture2D:
	if rank >= Ranks.SMALL_JOKER:
		return jokers[rank - Ranks.SMALL_JOKER]
	if rank >= Ranks.JACK and rank <= Ranks.KING:
		return court[rank - Ranks.JACK]
	return suits[suit]
