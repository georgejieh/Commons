class_name DeckChoice
extends RefCounted
## What the deck sheet shows while the player picks one deck card (ADR 0041, ADR 0042):
## its heading, the line before a card is picked, what picking one would do or why it
## cannot, and the confirm ticket's words. commit() acts through the run controller. A
## shop's desk gives one (DeskChoice), and so does a card bought for the deck at the state
## store (ExchangeChoice).


## The small line over the heading; each choice gives its own, and this one has none.
func eyebrow() -> String:
	return ""


## The heading over the deck while a card is picked; each choice gives its own.
func title() -> String:
	return ""


## The card coming into the deck, shown beside the heading, or null.
func incoming() -> CardInstance:
	return null


## The line before a card is picked.
func how() -> String:
	return ""


## The words on the confirm ticket, with the price where there is one.
func confirm_text() -> String:
	return ""


## Why the card cannot be picked, in words, or "" when it can.
func refusal(_card: CardInstance) -> String:
	return ""


## What picking the card does, once refusal() has found nothing.
func change(_card: CardInstance) -> String:
	return ""


## Acts on the picked card. False when the run refused it.
func commit(_controller: RunController, _card_id: int) -> bool:
	return false
