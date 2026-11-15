class_name EnvelopeDef
extends Resource
## One kind of envelope (ADR 0021), the packs of this game: bought in a shop, opened at
## once, it shows a few items, and the player keeps one or takes nothing. Each place in it
## is drawn by weight from what it holds. The code that draws and applies each kind of
## content is EnvelopeContents, chosen by kind, and every number it uses is here.

## What a place in an envelope can hold. Data does not name core types, so these stand
## for the kinds EnvelopeContents draws.
enum Content {
	## A Directive the selling counter offers, never one whose family is at the top level.
	DIRECTIVE,
	## A Campaign from the selling counter's Campaign pool.
	CAMPAIGN,
	## A new plot card carrying the player's stamp.
	STAMPED_CARD,
	## A new plot card with the Model enhancement.
	MODEL_CARD,
}

## How it looks on the counter and when it is opened.
enum Wrapping {
	## Manila, closed by a string wound round a button.
	STRING_TIE,
	## Brown paper, closed by a red wax seal.
	WAX_SEAL,
	## Wrapped in newspaper and tied with twine.
	PARCEL,
}

@export var id: String
@export var cost: int
## Finished runs needed before it is offered (P4.14). Nothing reads it yet.
@export var unlock_tier: int = 0
## Items it shows to choose from, before a Reform adds more.
@export var choices: int = 3
## What its places can hold, and the weight of each, in the same order.
@export var contents: Array[Content] = []
@export var weights: Array[int] = []
@export var wrapping: Wrapping = Wrapping.STRING_TIE
@export var name_key: String
@export var text_key: String
