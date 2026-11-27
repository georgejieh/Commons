class_name TableWild
extends RefCounted
## Wild ranks at the table (ADR 0029), from the run's events alone: a WILD_RANKS event
## names the ranks wild now, and a new deal clears them. When a rank becomes wild a
## call-out on red cloth names it, the rules strip names the round's wild ranks, every
## wild card in the hand and every one the player plays carries its ribbon, and a played
## stand-in names the rank it stands for. The ranks are the player's alone (ADR 0039): a
## villager's card of one lands on the pile plain, and the words say whose they are. It
## also holds the reading picker the table's Play opens when the chosen cards can be
## played more than one way now.

## The slip that asks which reading to play when the chosen cards can be played more than one way.
var picker: ReadingPicker = ReadingPicker.new()
## The ranks wild now as the events played so far have named them, in the order drawn.
var ranks: Array[int] = []

var _hand_view: HandView
var _pile: TrickPile
var _strip: DebuffStrip
var _moments: TableMoments
var _player: EventPlayer


## Puts the picker on the table, over everything the table shows.
func place(screen: Control) -> void:
	screen.add_child(picker)


## Wires the wild ranks to the hand, the pile, the rules slip, the moments, the event queue, the
## commands and the input, and gives the commands the picker.
func setup(
	hand_view: HandView,
	pile: TrickPile,
	strip: DebuffStrip,
	moments: TableMoments,
	player: EventPlayer,
	commands: TableCommands,
	input: TableInput
) -> void:
	_hand_view = hand_view
	_pile = pile
	_strip = strip
	_moments = moments
	_player = player
	commands.picker = picker
	input.picker = picker


## Acts on one event; quiet ones, from a replay or a skip, keep the ranks and show nothing.
func on_event(event: RunEvent, quiet: bool) -> void:
	match event.type:
		RunEvent.Type.SET_STARTED, RunEvent.Type.DEALT:
			picker.close()
			_show([])
		RunEvent.Type.WILD_RANKS:
			_show(event.listed())
			if not quiet:
				_shout(event.value)


## The ranks an event's text names.
func _show(now: Array[int]) -> void:
	ranks = now
	_hand_view.mark_wild(now)
	_pile.wild_ranks = now.duplicate()
	_strip.wild_ranks = now.duplicate()


## "Sevens are wild" across the screen; with two, the line under it names both.
func _shout(rank: int) -> void:
	var one: Array[int] = [rank]
	var word: String = ReadingText.wild_line(one)
	var sub: String = tr("callout.wild.sub")
	if ranks.size() > 1:
		var both: Dictionary = {"ranks": ReadingText.wild_line(ranks)}
		sub = tr("callout.wild.sub.two").format(both)
	_player.hold(_moments.callout.shout(word, Callout.Tier.CUT_IN, ScreenKit.RED, sub))
