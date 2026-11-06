extends GdUnitTestSuite
## Every card face is composed from CardArt parts (P3C.5): the 54 faces bind from the
## deck, and swapping one part restyles every card that uses it.

const SCENE: PackedScene = preload("res://ui/cards/card_view.tscn")
const DECK_SIZE: int = 54

var _views: Array[CardView] = []


func before_test() -> void:
	_views.clear()
	for deck_id: int in DECK_SIZE:
		var view: CardView = auto_free(SCENE.instantiate())
		add_child(view)
		_views.append(view)


func after_test() -> void:
	CardView.art_override = null


func test_all_54_faces_bind_from_parts() -> void:
	var art: CardArt = CardView.parts()
	for deck_id: int in DECK_SIZE:
		var card: CardInstance = CardInstance.from_deck_id(deck_id)
		var view: CardView = _views[deck_id]
		view.bind(card)
		var picture: TextureRect = view.get("_picture")
		var expected: Texture2D = _expected_picture(art, card)
		assert_object(picture.texture).is_same(ArtStages.resolve(expected))
		var rank: Label = view.get("_rank")
		assert_str(rank.text).is_not_empty()
		var suit: TextureRect = view.get("_suit")
		var joker: bool = card.base_rank() >= Ranks.SMALL_JOKER
		assert_bool(suit.visible).is_equal(not joker)


func test_changing_the_frame_restyles_every_card() -> void:
	var swapped: CardArt = CardView.parts().duplicate()
	swapped.frame = PlaceholderTexture2D.new()
	CardView.art_override = swapped
	var fresh: Array[CardView] = []
	for deck_id: int in DECK_SIZE:
		var view: CardView = auto_free(SCENE.instantiate())
		add_child(view)
		view.bind(CardInstance.from_deck_id(deck_id))
		fresh.append(view)
	for view: CardView in fresh:
		var frame: Panel = view.get("_frame")
		var stock: StyleBoxTexture = frame.get_theme_stylebox("panel") as StyleBoxTexture
		assert_object(stock.texture).is_same(swapped.frame)


func test_changing_a_suit_icon_restyles_that_suit_only() -> void:
	var swapped: CardArt = CardView.parts().duplicate()
	var hearts: Texture2D = PlaceholderTexture2D.new()
	swapped.suits = swapped.suits.duplicate()
	swapped.suits[1] = hearts
	CardView.art_override = swapped
	for deck_id: int in DECK_SIZE:
		var card: CardInstance = CardInstance.from_deck_id(deck_id)
		_views[deck_id].bind(card)
		var suit: TextureRect = _views[deck_id].get("_suit")
		if card.base_rank() < Ranks.SMALL_JOKER:
			assert_bool(suit.texture == hearts).is_equal(card.suit() == 1)


func test_the_card_stock_is_lit_through_its_normal_map() -> void:
	_views[0].bind(CardInstance.from_deck_id(0))
	var frame: Panel = _views[0].get("_frame")
	var stock: StyleBoxTexture = frame.get_theme_stylebox("panel") as StyleBoxTexture
	var canvas: CanvasTexture = stock.texture as CanvasTexture
	assert_object(canvas).is_not_null()
	assert_object(canvas.normal_texture).is_not_null()
	assert_int(frame.light_mask).is_equal(Lighting.MASK)


## What each rank shows in the middle, written out rather than asked of CardArt: pips
## (3 to 10, ace and two) show their suit, jack to king their court art, jokers theirs.
func _expected_picture(art: CardArt, card: CardInstance) -> Texture2D:
	match card.base_rank():
		Ranks.JACK:
			return art.court[0]
		Ranks.QUEEN:
			return art.court[1]
		Ranks.KING:
			return art.court[2]
		Ranks.SMALL_JOKER:
			return art.jokers[0]
		Ranks.BIG_JOKER:
			return art.jokers[1]
	return art.suits[card.suit()]
