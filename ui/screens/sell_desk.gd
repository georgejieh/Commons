class_name SellDesk
extends RefCounted
## Selling back what the player holds, in either shop (ADR 0040): each held Cadre on the
## board and each held Campaign in the tray carries a SellTag that names what this
## counter pays for it. Its rules show in the shop's slip while the paper has the focus,
## as the engine's tooltip shows them under the pointer. A sale goes through the run
## controller; the screen hears of it from the run's CADRE_SOLD or CAMPAIGN_SOLD event,
## counts the coupons up and shows the freed place. The tickets follow the tray: whenever
## it lays out what is held again, as after a Campaign is bought or used here, every
## ticket names the item now on its paper, and a question left on a paper whose item
## changed is taken back.

## A sale went through: the coupons and the board changed. campaign is set for a held
## Campaign, clear for a held Cadre.
signal sold(campaign: bool)

var _app: DemoApp
var _market: bool = false
var _desk: ShopDesk
var _board: NoticeBoard
var _tray: CampaignTray
var _slip: DetailSlip
var _busy: Callable = Callable()
var _tags: Dictionary[Control, SellTag] = {}


func setup(
	app: DemoApp,
	market: bool,
	desk: ShopDesk,
	board: NoticeBoard,
	tray: CampaignTray,
	slip: DetailSlip,
	busy: Callable
) -> void:
	_app = app
	_market = market
	_desk = desk
	_board = board
	_tray = tray
	_slip = slip
	_busy = busy
	app.controller.event_emitted.connect(_on_event)
	tray.refreshed.connect(refresh)


## Offers every held item for sale at this counter's price now.
func refresh() -> void:
	var controller: RunController = _app.controller
	var cadres: Array[String] = controller.run.held_cadres()
	var index: int = 0
	for node: Node in _board.get_children():
		if not node is TipHost:
			continue
		var tag: SellTag = _tag(node as Control, false)
		if index < cadres.size():
			var paid: int = _desk.sale(index)
			tag.offer(paid, "" if paid > 0 else tr("store.sell.bound"), cadres[index])
		else:
			tag.withdraw()
		index += 1
	var held: Array[String] = controller.items.held_campaigns()
	for slot: int in _tray.campaign_count():
		var tag: SellTag = _tag(_tray.leaflet(slot), true)
		if slot < held.size():
			tag.offer(_desk.sale(slot, true), "", held[slot])
		else:
			tag.withdraw()


## The tag on a held item's paper, for tests: a board card or a tray leaflet.
func tag_on(paper: Control) -> SellTag:
	return _tags.get(paper)


func _tag(paper: Control, campaign: bool) -> SellTag:
	if _tags.has(paper):
		return _tags[paper]
	var tag: SellTag = SellTag.attach(paper)
	tag.confirmed.connect(_sell.bind(paper, campaign))
	tag.focus_changed.connect(_explain.bind(paper, campaign))
	_tags[paper] = tag
	return tag


## Where paper stands among the held items of its kind.
func _index(paper: Control, campaign: bool) -> int:
	if campaign:
		return (paper as CampaignLeaflet).slot
	var index: int = 0
	for node: Node in _board.get_children():
		if node == paper:
			return index
		if node is TipHost:
			index += 1
	return -1


func _sell(paper: Control, campaign: bool) -> void:
	# The arrival teaches buying; it refuses a sale as it refuses any step it is not on.
	if (_busy.is_valid() and bool(_busy.call())) or not _app.arrival.allows("sell"):
		return
	var index: int = _index(paper, campaign)
	if campaign:
		_app.controller.sell_campaign(index, _market)
	else:
		_app.controller.sell_cadre(index, _market)


## The rules of a focused paper's item in the shop's slip, for keyboard and gamepad.
func _explain(focused: bool, paper: Control, campaign: bool) -> void:
	if not focused:
		_slip.hide_for(paper)
		return
	var index: int = _index(paper, campaign)
	var controller: RunController = _app.controller
	if campaign:
		var held: Array[String] = controller.items.held_campaigns()
		if index >= 0 and index < held.size():
			var id: String = held[index]
			_slip.show_for(
				paper, controller.texts.campaign_name(id), controller.texts.campaign_text(id)
			)
		return
	var cadres: Array[String] = controller.run.held_cadres()
	if index >= 0 and index < cadres.size():
		var title: String = tr("modifier.%s.name" % cadres[index])
		_slip.show_for(paper, title, ScreenKit.rule_text(controller, cadres[index]))


func _on_event(event: RunEvent) -> void:
	var kind: RunEvent.Type = event.type
	if kind != RunEvent.Type.CADRE_SOLD and kind != RunEvent.Type.CAMPAIGN_SOLD:
		return
	Audio.play(AudioEvents.STORE_BUY)
	_slip.hide_slip()
	sold.emit(kind == RunEvent.Type.CAMPAIGN_SOLD)
