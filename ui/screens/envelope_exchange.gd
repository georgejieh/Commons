class_name EnvelopeExchange
extends RefCounted
## Keeping a card for the deck from an open envelope (ADR 0042): the deck sheet opens over
## the envelope on an ExchangeChoice, and the pick is sent only once the player confirms
## the deck card that leaves. Backing out of the sheet leaves the envelope open at its
## choice, with nothing kept and nothing lost.

var _sheet: DeckSheet
## Called with the item's index once its exchange is made, and once the player backed out.
var _kept: Callable
var _backed: Callable
var _pending: int = -1


func _init(sheet: DeckSheet, kept: Callable, backed: Callable) -> void:
	_sheet = sheet
	_kept = kept
	_backed = backed


## True while the sheet asks for the deck card an item replaces.
func is_open() -> bool:
	return _pending >= 0


## Asks for the deck card the shelf's item at index replaces.
func ask(controller: RunController, shelf: EnvelopeShelf, index: int) -> void:
	_pending = index
	var refuse: Callable = func(out: int) -> String: return shelf.exchange_refusal(index, out)
	var act: Callable = func(out: int) -> int: return controller.envelope_pick(index, out)
	var confirm: String = tr("exchange.confirm.kept")
	_sheet.chosen.connect(_on_chosen, CONNECT_ONE_SHOT)
	_sheet.closed.connect(_on_closed, CONNECT_ONE_SHOT)
	_sheet.open_choice(ExchangeChoice.new(shelf.card(index), confirm, refuse, act))


func _on_chosen(_card_id: int) -> void:
	if _sheet.closed.is_connected(_on_closed):
		_sheet.closed.disconnect(_on_closed)
	var index: int = _pending
	_pending = -1
	_kept.call(index)


func _on_closed() -> void:
	if _sheet.chosen.is_connected(_on_chosen):
		_sheet.chosen.disconnect(_on_chosen)
	var index: int = _pending
	_pending = -1
	_backed.call(index)
