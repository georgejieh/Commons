class_name CampaignDef
extends Resource
## One Campaign (ADR 0021): a one-use item the player holds and spends at the moment its
## rule names. Its behaviour is a small effect script registered by ID in
## CampaignRegistry, and every number it uses is in parameters.

## When it may be used. Data does not name the loop's states, so these stand for them.
enum When {
	## On your turn in a round.
	TURN,
	## Before the round's first play: at the opening, or on the landlord's first turn.
	OPENING,
	## On your turn in a round, or in either shop.
	TURN_OR_SHOP,
}

## The ID the registries, the saves and the pools name it by.
@export var id: String
## Whether it is collective or private.
@export var tag: ModifierDef.Tag
## What it costs at the counter, in coupons.
@export var cost: int
## Finished runs needed before it is offered; RunUnlocks reads it (ADR 0025).
@export var unlock_tier: int = 0
## When it may be used.
@export var when: When
## How many of the player's hand cards it asks for: from min_cards to max_cards.
@export var min_cards: int = 0
## The most cards of the hand it asks for.
@export var max_cards: int = 0
## The numbers its effect script reads, by name.
@export var parameters: Dictionary[String, int]
## The string key of its name.
@export var name_key: String
## The string key of its rules text.
@export var text_key: String
## What the prompt line asks while it is armed.
@export var prompt_key: String


## The values that fill the rules text and the prompt: the parameters and the card counts.
func text_values() -> Dictionary[String, Variant]:
	var values: Dictionary[String, Variant] = ModifierDef.text_numbers(parameters, [])
	values["min_cards"] = min_cards
	values["max_cards"] = max_cards
	return values
