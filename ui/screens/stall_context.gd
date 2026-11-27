class_name StallContext
extends RefCounted
## What every stall on a shop's page is set up with: the app and its run, which shop this
## is, the page's shared slip and deck sheet, the shop's desk, and the page's question
## whether anything is being acted out. A stall reports a purchase made on the page by its
## spent signal; one made through the deck sheet is reported by the sheet's chosen.

## The app whose run the stalls act on.
var app: App
## The run's controller, which every purchase goes through.
var controller: RunController
## True for the black market, false for the state store.
var market: bool
## The shop's desk, from which the stalls read what is on sale and its price.
var desk: ShopDesk
## Explains whatever on the page is hovered or holds the focus.
var slip: DetailSlip
## The page's deck sheet, where a purchase that picks one of the deck's cards is made.
var deck: DeckSheet
## Returns true while the page acts out a purchase or a question stands over it, when no
## stall takes another.
var busy: Callable


func _init(
	shop_app: App, in_market: bool, page_slip: DetailSlip, sheet: DeckSheet, page_busy: Callable
) -> void:
	app = shop_app
	controller = shop_app.controller
	market = in_market
	desk = controller.store.desk(in_market)
	slip = page_slip
	deck = sheet
	busy = page_busy
