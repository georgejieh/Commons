class_name NoticeBoard
extends HBoxContainer
## The player's Cadres as portrait cards pinned in slot order. Slots are made once. A card
## shows its art; its name and rules are in its tooltip, a slip that also says what each
## keyword in the rules means. A Cadre with run state carries a short count on a ticket
## at its foot, and a Cadre with no art yet has its name inked on the stock (ADR 0021).
## When a Cadre fires, its card swells and its count changes there, not over the table.
## There is a slot for every Cadre the player can hold; the cards shrink to keep the
## board inside its box when a Reform adds one. A Cadre a Confiscation leaves out of the
## round is struck through and stamped for that round (ADR 0023). A board given an empty
## line, as the shops give theirs, prints it across its slots while it holds no Cadre.

## How faint an empty Cadre slot is.
const EMPTY_ALPHA: float = 0.22
## A Cadre card's size at full size, in pixels.
const TILE_SIZE: Vector2 = Vector2(108, 140)
## The gap between cards, in pixels.
const GAP: int = 14
## How far a Cadre's card swings on its pin, in radians, when it changes a play's score.
const JIGGLE: float = 0.1
## How far a Cadre's card swells when it changes a play's score, as a scale.
const JIGGLE_SCALE: float = 1.08
## Where a Cadre's card keeps the tween that swings it on its pin.
const SWING_META: StringName = &"notice_board_swing"
## Where a Cadre's card keeps the tween that swells it as it swings.
const SWELL_META: StringName = &"notice_board_swell"
## The empty line's type size.
const EMPTY_SIZE: int = 18
## The width of the paper halo round the empty line, in pixels.
const EMPTY_HALO: int = 5

## Printed across the slots while no Cadre is held; empty for none, as at the table.
var empty_line: String = ""

## The papers pinned on the board, one for each held Cadre, in slot order.
var cards: Array[TipHost] = []
## Each slot's Cadre art, in slot order, for tests and tools.
var pictures: Array[TextureRect] = []
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
	while cards.size() < slots:
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
		cards.append(card)
		pictures.append(picture)
		_badges.append(badge)
	for card: TipHost in cards:
		card.custom_minimum_size = tile_size(cards.size())


## How many slots the board has.
func slot_count() -> int:
	return cards.size()


## Where a slot's card sits on screen, its middle.
func slot_center(index: int) -> Vector2:
	var card: TipHost = cards[clampi(index, 0, cards.size() - 1)]
	return card.global_position + card.size / 2.0


## Swells a slot's card, as when a Cadre is pinned to it.
func pulse_slot(index: int) -> void:
	if index >= 0 and index < cards.size():
		UiMotion.pulse(cards[index])


## A held Cadre fired: its card swells, and its count shows what it is now, or what it
## paid for a Cadre that keeps no count.
func fired(controller: RunController, cadre_id: String, amount: int) -> void:
	var index: int = _ids.find(cadre_id)
	if index < 0:
		return
	var count: String = controller.items.cadre_standing(cadre_id).count
	_badges[index].show_count(count if not count.is_empty() else "+%d" % amount)
	pulse_slot(index)


## A held Cadre changed a play's score as it was counted: its card jiggles on its pin,
## unless motion is reduced, and its count shows what it is now. Returns where the card
## stands on screen, or an empty box when the Cadre is not on the board.
func jiggle(controller: RunController, cadre_id: String, seconds: float) -> Rect2:
	var index: int = _ids.find(cadre_id)
	if index < 0 or not is_visible_in_tree():
		return Rect2()
	var card: TipHost = cards[index]
	var count: String = controller.items.cadre_standing(cadre_id).count
	if not count.is_empty():
		_badges[index].show_count(count)
	if not UiMotion.reduced() and seconds > 0.0:
		card.pivot_offset = card.size / 2.0
		var wobble: Tween = UiMotion.hold(card, SWING_META, card.create_tween())
		wobble.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var swings: Array[float] = [JIGGLE, -JIGGLE * 0.7, JIGGLE * 0.4, 0.0]
		for angle: float in swings:
			wobble.tween_property(card, "rotation", angle, seconds / swings.size())
		var swell: Tween = UiMotion.hold(card, SWELL_META, card.create_tween())
		swell.tween_property(card, "scale", Vector2.ONE * JIGGLE_SCALE, seconds * 0.3)
		swell.tween_property(card, "scale", Vector2.ONE, seconds * 0.7)
	return card.get_global_rect()


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
	_grow(controller.figures.cadre_slots())
	var cadre_ids: Array[String] = controller.run.held_cadres()
	var confiscated: Array[String] = controller.items.confiscated_cadres()
	_ids = cadre_ids
	for index: int in cards.size():
		var held: bool = index < cadre_ids.size()
		# An empty slot is a faint pin mark on the board, so it doesn't pull the eye.
		cards[index].modulate.a = 1.0 if held else EMPTY_ALPHA
		var struck: bool = held and confiscated.has(cadre_ids[index])
		if struck and not _marks[index].visible:
			_marks[index].strike(false)
		_marks[index].visible = struck
		if held:
			var title: String = tr("modifier.%s.name" % cadre_ids[index])
			var rule: String = ScreenKit.rule_text(controller, cadre_ids[index])
			if struck:
				rule = tr("table.confiscated_tip") + " " + rule
			cards[index].set_tip(title, rule)
		else:
			cards[index].set_tip("", "")
		pictures[index].texture = ScreenKit.cadre_art(cadre_ids[index]) if held else null
		var bare: bool = held and not ScreenKit.ART.has_cadre(cadre_ids[index])
		_badges[index].show_name(tr("modifier.%s.name" % cadre_ids[index]) if bare else "")
		_badges[index].show_count(
			controller.items.cadre_standing(cadre_ids[index]).count if held else ""
		)
	queue_redraw()


## True while the board shows its empty line, for tests.
func shows_empty_line() -> bool:
	return _ids.is_empty() and not empty_line.is_empty()


func _draw() -> void:
	if not shows_empty_line():
		return
	var font: Font = get_theme_default_font()
	var px: int = TextSize.px(EMPTY_SIZE)
	var wide: float = font.get_string_size(empty_line, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var at: Vector2 = Vector2((size.x - wide) / 2.0, size.y / 2.0 + font.get_ascent(px) * 0.4)
	var halo: Color = CampaignPaper.paper(BowlGrime.wear())
	draw_string_outline(font, at, empty_line, HORIZONTAL_ALIGNMENT_LEFT, -1, px, EMPTY_HALO, halo)
	draw_string(font, at, empty_line, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ScreenKit.INK)
