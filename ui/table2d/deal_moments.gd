class_name DealMoments
extends Control
## What a deal shows the player before the bid (ADR 0043), on the trick pile while it is
## still empty. Cards a boss sets aside rise from the hand and lie face up under a stamped
## word and a note naming them, then are swept off the table: they are out of the round,
## and the rules slip names them from then on. The kitty an information Cadre shows lies
## face up where the kitty is revealed, under a note that only the player sees it, until
## the seat is chosen and the kitty's own reveal takes the pile.
## Reduced motion, a replay or a skip drop the set-aside beat, whose cards the slip still
## names, and lay the kitty there still.

## The stamped word's type at Standard.
const WORD_SIZE: int = 34
## The stamped word's outline, in pixels.
const WORD_OUTLINE: int = 10
## The note's type at Standard.
const NOTE_SIZE: int = 18
## The note's paper padding, in pixels.
const NOTE_PADDING: int = 22
## Where the word stands: where the kitty's label does.
const WORD_AT: Vector2 = KittyShow.LABEL_AT
## How far under the lowest a laid card can reach the note stands, in pixels, so it never
## covers one.
const NOTE_GAP: float = 12.0
## How long the set-aside cards lie face up before they leave, in seconds.
const ASIDE_SHOW: float = 1.4
## Where the set-aside cards are swept to: off the top of the table, away from every seat.
const OFF_TABLE: Vector2 = Vector2(790, -240)
## Seconds the queue is held after the sweep, so the next beat does not start on it.
const MARGIN: float = 0.12

var _controller: RunController
var _pile: TrickPile
var _hand_view: HandView
var _player: EventPlayer
var _word: Label = Label.new()
var _note: PanelContainer = PanelContainer.new()
var _note_text: Label = Label.new()
var _beat: Tween = null
## True while the kitty the player alone sees lies on the pile.
var _kitty_shown: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_word.theme_type_variation = CommonsTheme.TITLE
	_word.add_theme_font_size_override("font_size", TextSize.px(WORD_SIZE))
	_word.add_theme_color_override("font_color", ScreenKit.STYLE.paper_bright)
	_word.add_theme_color_override("font_outline_color", ScreenKit.INK)
	_word.add_theme_constant_override("outline_size", WORD_OUTLINE)
	_word.visible = false
	add_child(_word)
	_note.add_theme_stylebox_override("panel", ScreenKit.paper_style(NOTE_PADDING))
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.visible = false
	_note_text.add_theme_font_size_override("font_size", TextSize.px(NOTE_SIZE))
	_note_text.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
	_note_text.add_theme_color_override("font_color", ScreenKit.INK)
	_note.add_child(_note_text)
	add_child(_note)


## Lies over the whole screen, just under the moments layer, so a call-out dims it too.
func place(screen: Control, moments: TableMoments) -> void:
	screen.add_child(self)
	screen.move_child(self, moments.get_index())
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Wires the deal's moments to the run's controller, the trick pile, the hand and the event queue,
## and plays each event the queue releases.
func setup(
	controller: RunController, pile: TrickPile, hand_view: HandView, player: EventPlayer
) -> void:
	_controller = controller
	_pile = pile
	_hand_view = hand_view
	_player = player
	player.played.connect(func(event: RunEvent) -> void: on_event(event, player.flushing))


## Acts out event. quiet keeps the end state and drops the show.
func on_event(event: RunEvent, quiet: bool) -> void:
	match event.type:
		RunEvent.Type.SET_STARTED, RunEvent.Type.DEALT, RunEvent.Type.REDEALT:
			_put_away()
		RunEvent.Type.LANDLORD_CHOSEN:
			# The kitty's own reveal follows at once and takes the pile.
			if _kitty_shown:
				_pile.clear()
			_put_away()
		RunEvent.Type.CARDS_SET_ASIDE:
			if not quiet and not UiMotion.reduced() and _player.step > 0.0:
				_set_aside(_cards(event))
		RunEvent.Type.KITTY_SEEN:
			_see_kitty(_cards(event))


## The note's words while it shows, for tests.
func note_text() -> String:
	return _note_text.text if _note.visible else ""


## True while the kitty the player alone sees lies on the pile, for tests.
func kitty_shown() -> bool:
	return _kitty_shown


func _set_aside(cards: Array[CardInstance]) -> void:
	if cards.is_empty():
		return
	_put_away()
	_pile.clear()
	_pile.show_play(cards, _hand_view.global_position + _hand_view.size / 2.0)
	var names: PackedStringArray = []
	for card: CardInstance in cards:
		names.append(CardName.of(card))
	var boss: String = _controller.texts.modifier_name(_controller.items.boss())
	_show_words(
		tr("table.set_aside_word"),
		tr("beat.set_aside").format({"name": boss, "cards": ", ".join(names)}),
	)
	_beat = create_tween()
	_beat.tween_interval(ASIDE_SHOW)
	_beat.tween_callback(_pile.sweep.bind(OFF_TABLE))
	_beat.tween_callback(_put_away)
	_player.hold(ASIDE_SHOW + UiMotion.PRESETS.sweep + MARGIN)


func _see_kitty(cards: Array[CardInstance]) -> void:
	if cards.is_empty():
		return
	_put_away()
	_pile.clear()
	_pile.show_play(cards, KittyShow.FROM)
	_show_words(tr("keyword.kitty.name"), tr("table.kitty_seen"))
	_kitty_shown = true


func _show_words(word: String, note: String) -> void:
	_word.text = word.to_upper()
	_word.reset_size()
	_word.position = WORD_AT - _word.size / 2.0
	_word.visible = true
	UiMotion.stamp(_word)
	_note_text.text = note
	_note.reset_size()
	var below: float = _pile.global_position.y + _pile.reach_below() + NOTE_GAP
	_note.position = Vector2(WORD_AT.x - _note.size.x / 2.0, below) - global_position
	_note.visible = true


func _put_away() -> void:
	UiMotion.end(_beat)
	_beat = null
	_word.visible = false
	_note.visible = false
	_kitty_shown = false


## The deck cards an event names by ID, as the deal made them.
func _cards(event: RunEvent) -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for card_id: int in event.listed():
		if card_id < Deck.SIZE:
			cards.append(_controller.table.deck_card(card_id))
	return cards
