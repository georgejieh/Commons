class_name BalanceVisit
extends RefCounted
## A shop visit as a strategy sees it at one moment: its coupons and Resentment, what
## each counter offers that it can buy now, and what it has done this visit.

var coupons: int = 0
var resentment: int = 0
var store: Array[BalanceOffer] = []
var market: Array[BalanceOffer] = []
## Black market purchases made this visit.
var market_bought: int = 0
var rerolled: bool = false
## True when a black market reroll is affordable and could change the counter.
var can_reroll: bool = false
