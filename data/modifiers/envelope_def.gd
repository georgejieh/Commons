class_name EnvelopeDef
extends Resource
## One kind of envelope (ADR 0021), the packs of this game: bought in a shop, opened at
## once, it shows a few items, and the player keeps one or takes nothing. Each place in it
## is drawn by weight from what it holds. The code that draws and applies each kind of
## content is EnvelopeContents, chosen by kind, and every number it uses is here.

## What a place in an envelope can hold: the kinds EnvelopeContents draws.
enum Content {
	## A Directive the selling counter offers, never one whose family is at the top level.
	DIRECTIVE,
	## A Campaign from the selling counter's Campaign pool.
	CAMPAIGN,
	## A new plot card carrying the player's stamp.
	STAMPED_CARD,
	## A new plot card with the Model enhancement.
	MODEL_CARD,
	## A card for the communal deck, which takes the place of a deck card the player names
	## (ADR 0042).
	DECK_CARD,
	## A card for the communal deck carrying an enhancement, drawn evenly from them all.
	MARKED_DECK_CARD,
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

## The ID the registries, the saves and the pools name it by.
@export var id: String
## What it costs at the counter, in coupons.
@export var cost: int
## Finished runs needed before it is offered; RunUnlocks reads it (ADR 0025).
@export var unlock_tier: int = 0
## Items it shows to choose from, before a Reform adds more.
@export var choices: int = 3
## What its places can hold.
@export var contents: Array[Content] = []
## The weight of each of those contents, in the same order.
@export var weights: Array[int] = []
## How it looks on the counter and when it is opened.
@export var wrapping: Wrapping = Wrapping.STRING_TIE
## The string key of its name.
@export var name_key: String
## The string key of its rules text.
@export var text_key: String
