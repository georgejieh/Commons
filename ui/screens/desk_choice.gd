class_name DeskChoice
extends DeckChoice
## Picking the deck card a shop's desk marks (ADR 0041): the state store's gives the
## visit's enhancement, the black market's stamps the card as the player's. The sheet says
## what the card will lose, or why the desk refuses it, and the confirm ticket names the
## price.

var _desk: DeskView
var _market: bool


func _init(desk: DeskView, market: bool) -> void:
	_desk = desk
	_market = market


func eyebrow() -> String:
	return tr("deck.desk.market" if _market else "deck.desk.store")


func title() -> String:
	if _desk.stamps():
		return tr("deck.desk.stamp_title")
	return tr("deck.desk.title").format({"mark": DeckSheet.mark_name(_desk.offer())})


func how() -> String:
	return tr("deck.desk.how")


func confirm_text() -> String:
	var key: String = "deck.desk.stamp" if _desk.stamps() else "deck.desk.mark"
	return tr(key).format({"price": _desk.price()})


func refusal(card: CardInstance) -> String:
	var key: String = _desk.refusal(card.id())
	return "" if key.is_empty() else tr(key).format(_values(card))


func change(card: CardInstance) -> String:
	if _desk.stamps():
		return tr("deck.change.stamp").format(_values(card))
	if CardMark.draws(card.enhancement_id()):
		return tr("deck.change.replace").format(_values(card))
	return tr("deck.change.mark").format(_values(card))


func commit(controller: RunController, card_id: int) -> bool:
	return controller.mark_card(card_id, _market) == RunController.OK


func _values(card: CardInstance) -> Dictionary[String, Variant]:
	return {
		"card": CardName.of(card),
		"mark": DeckSheet.mark_name(_desk.offer()),
		"old": DeckSheet.mark_name(card.enhancement_id()),
		"price": _desk.price(),
	}
