class_name NoticeBoard
extends HBoxContainer
## The player's Cadres as portrait cards pinned in slot order. Slots are made once. A card
## shows its art; its name and rules are in its tooltip, a slip that also says what each
## keyword in the rules means. A Cadre with run state carries a short count on a ticket
## at its foot, and a Cadre with no art yet has its name inked on the stock (ADR 0021).
## When a Cadre fires, its card swells and its count changes there, not over the table.
## There is a slot for every Cadre the player can hold; the cards shrink to keep the
## board inside its box when a Reform adds one. A Cadre a Confiscation leaves out of the
## round is struck through and stamped for that round (ADR 0023).

## How faint an empty Cadre slot is.
const EMPTY_ALPHA: float = 0.22
const TILE_SIZE: Vector2 = Vector2(108, 140)
const GAP: int = 14

var _pictures: Array[TextureRect] = []
var _cards: Array[TipHost] = []
var _badges: Array[CadreBadge] = []
var _marks: Array[ConfiscatedMark] = []
var _ids: Array[String] = []
## The most room the board may take; zero for none, which keeps full-size cards.
var _box: Vector2 = Vector2.ZERO


## Makes one slot per Cadre the player can hold, sized to fit box when one is given.
func setup(slots: int, box: Vector2 = Vector2.ZERO) -> void:
	_box = box
	add_theme_constant_override("separation", GAP)
	alignment = BoxContainer.ALIGNMENT_CENTER
	_grow(slots)


## The size of each card for a number of slots: full size, or smaller to fit the box.
func tile_size(slots: int) -> Vector2:
	if _box == Vector2.ZERO or slots <= 0:
		return TILE_SIZE
	var wide: float = (_box.x - (slots - 1) * GAP) / slots
	var fit: float = minf(1.0, minf(wide / TILE_SIZE.x, _box.y / TILE_SIZE.y))
	return (TILE_SIZE * fit).floor()


## Adds slots up to the count, and sizes every card for it.
func _grow(slots: int) -> void:
	while _cards.size() < slots:
		var card: TipHost = TipHost.new()
		card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		card.add_theme_stylebox_override("panel", ScreenKit.paper_style(6))
		var picture: TextureRect = TextureRect.new()
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(picture)
		var badge: CadreBadge = CadreBadge.new()
		card.add_child(badge)
		var mark: ConfiscatedMark = ConfiscatedMark.new()
		card.add_child(mark)
		_marks.append(mark)
		add_child(card)
		_cards.append(card)
		_pictures.append(picture)
		_badges.append(badge)
	for card: TipHost in _cards:
		card.custom_minimum_size = tile_size(_cards.size())


## How many slots the board has.
func slot_count() -> int:
	return _cards.size()


## Where a slot's card sits on screen, its middle.
func slot_center(index: int) -> Vector2:
	var card: TipHost = _cards[clampi(index, 0, _cards.size() - 1)]
	return card.global_position + card.size / 2.0


## Swells a slot's card, as when a Cadre is pinned to it.
func pulse_slot(index: int) -> void:
	if index >= 0 and index < _cards.size():
		UiMotion.pulse(_cards[index])


## A held Cadre fired: its card swells, and its count shows what it is now, or what it
## paid for a Cadre that keeps no count.
func fired(controller: RunController, cadre_id: String, amount: int) -> void:
	var index: int = _ids.find(cadre_id)
	if index < 0:
		return
	var count: String = controller.cadre_standing(cadre_id).count
	_badges[index].show_count(count if not count.is_empty() else "+%d" % amount)
	pulse_slot(index)


## Strikes a slot's card out for the round; animate presses the stamp on like ink.
func strike(index: int, animate: bool) -> void:
	if index >= 0 and index < _marks.size():
		_marks[index].strike(animate)


## True while a slot's card is struck out, for tests.
func is_struck(index: int) -> bool:
	return _marks[index].visible


## The count a slot's card shows, for tests.
func count_at(index: int) -> String:
	return _badges[index].count()


## Shows the Cadres the run holds, each with its name and rules as its tooltip.
func show_cadres(controller: RunController) -> void:
	_grow(controller.cadre_slots())
	var cadre_ids: Array[String] = controller.state_copy().inventory.cadres
	var confiscated: Array[String] = controller.confiscated_cadres()
	_ids = cadre_ids
	for index: int in _cards.size():
		var held: bool = index < cadre_ids.size()
		# An empty slot is a faint pin mark on the board, so it doesn't pull the eye.
		_cards[index].modulate.a = 1.0 if held else EMPTY_ALPHA
		var struck: bool = held and confiscated.has(cadre_ids[index])
		if struck and not _marks[index].visible:
			_marks[index].strike(false)
		_marks[index].visible = struck
		if held:
			var name: String = tr("modifier.%s.name" % cadre_ids[index])
			var rule: String = ScreenKit.rule_text(controller, cadre_ids[index])
			if struck:
				rule = tr("table.confiscated_tip") + " " + rule
			_cards[index].set_tip(name, rule)
		else:
			_cards[index].set_tip("", "")
		_pictures[index].texture = ScreenKit.cadre_art(cadre_ids[index]) if held else null
		var bare: bool = held and ScreenKit.ART.cadre(cadre_ids[index]) == null
		_badges[index].show_name(tr("modifier.%s.name" % cadre_ids[index]) if bare else "")
		_badges[index].show_count(controller.cadre_standing(cadre_ids[index]).count if held else "")
