class_name ExchangeChoice
extends DeckChoice
## Picking the deck card a card bought for the deck replaces (ADR 0042), from the state
## store's stall or a Requisition envelope. The heading shows the card coming in; once a
## card is picked the sheet names both, "In: King of Spades, Model. Out: 3 of Hearts.",
## before the player confirms, and Back leaves everything as it was.

var _card: CardInstance
var _confirm: String
## Takes the slot of the deck card picked: the key of the words that refuse it, or "".
var _refuse: Callable
## Takes the slot of the deck card picked and makes the exchange: RunController.OK or not.
var _act: Callable


func _init(card: CardInstance, confirm: String, refuse: Callable, act: Callable) -> void:
	_card = card
	_confirm = confirm
	_refuse = refuse
	_act = act


## A card's name with its enhancement, "King of Spades, Model", or its name alone.
static func card_text(card: CardInstance) -> String:
	var named: String = CardName.of(card)
	if not CardMark.draws(card.enhancement_id()):
		return named
	var mark: String = DeckSheet.mark_name(card.enhancement_id())
	return TranslationServer.translate("exchange.card").format({"card": named, "mark": mark})


func eyebrow() -> String:
	return tr("exchange.eyebrow")


func title() -> String:
	return tr("exchange.title")


func incoming() -> CardInstance:
	return _card


func how() -> String:
	return tr("exchange.how").format({"card": card_text(_card)})


func confirm_text() -> String:
	return _confirm


func refusal(card: CardInstance) -> String:
	var key: String = str(_refuse.call(card.id()))
	return "" if key.is_empty() else tr(key)


func change(card: CardInstance) -> String:
	var values: Dictionary[String, Variant] = {"in": card_text(_card), "out": CardName.of(card)}
	var marks: PackedStringArray = []
	if CardMark.draws(card.enhancement_id()):
		marks.append(DeckSheet.mark_name(card.enhancement_id()))
	if card.owner_stamp() == Seats.PLAYER:
		marks.append(DeckSheet.mark_name(DeckSheet.STAMP))
	if marks.is_empty():
		return tr("exchange.change").format(values)
	values["marks"] = marks[0]
	if marks.size() > 1:
		values["marks"] = tr("exchange.marks.both").format({"first": marks[0], "second": marks[1]})
	return tr("exchange.change.marked").format(values)


func commit(_controller: RunController, card_id: int) -> bool:
	return int(_act.call(card_id)) == RunController.OK
