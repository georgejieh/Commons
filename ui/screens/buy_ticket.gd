class_name BuyTicket
extends RefCounted
## What a shop's Buy button says. One that can be pressed says "Buy" and the price. One
## that cannot says why in place of "Buy": "Need 8 coupons" while the coupons are short,
## "No room" while the board, the tray or the plot is full (no price, which would not fit
## a counter paper at the largest text), "Back next visit" for an item sold back this
## visit, and "Rank full" for a card for the deck of a rank it holds the most of (ADR
## 0042), whatever the coupons. Off, its words are dark ink that reads on the faded
## ticket, in colour and in grayscale.

## Why a Buy ticket cannot be pressed: NONE when it can, then the coupons short, no room, an empty
## place, an item sold back this visit, or a rank held at its most.
enum Why { NONE, POOR, FULL, EMPTY, SOLD_BACK, AT_MOST }

## Ink on a ticket that cannot be pressed: dark enough to read, a little faded.
const OFF_INK: Color = Color(0.118, 0.102, 0.086, 0.82)


## Sets button for an item at price: enabled when can, else off with its reason, which
## is short coupons when coupons fall below price, and otherwise the reason given.
static func dress(
	button: Button, can: bool, price: int, coupons: int, otherwise: Why = Why.FULL
) -> void:
	button.disabled = not can
	var why: Why = Why.NONE
	if not can:
		var settled: bool = otherwise == Why.SOLD_BACK or otherwise == Why.AT_MOST
		why = Why.POOR if coupons < price and not settled else otherwise
	button.text = words(why, price)
	readable(button)


## The words on a Buy button for why it is off, or for one that is on.
static func words(why: Why, price: int) -> String:
	var key: String = "store.buy"
	match why:
		Why.POOR:
			key = "store.buy.poor"
		Why.FULL:
			key = "store.buy.full"
		Why.EMPTY:
			key = "store.buy.empty"
		Why.SOLD_BACK:
			key = "store.buy.sold_back"
		Why.AT_MOST:
			key = "store.buy.at_most"
	return TranslationServer.translate(key).format({"price": price})


## Any shop button reads while it is off.
static func readable(button: Button) -> void:
	button.add_theme_color_override("font_disabled_color", OFF_INK)
