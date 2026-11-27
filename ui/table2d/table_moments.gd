class_name TableMoments
extends Control
## The table acted out, as one layer over the play area. Small beats stay where they
## happen: a pass is tagged on the seat that passed, a card lands with weight, a score is
## acted out on chits under the trick (ScoreSequence) and flies to the ledger. Big beats
## take the whole screen for a moment through the Callout: a call or grab for the landlord
## seat, a bomb, the end of a round. It holds the event queue still for as long as each
## beat needs, and shows only what the run already says; the ledger, seats and meters hold
## the same facts at rest.

## Where the audit slip sits, its middle. The tally keeps to the room ScoreSequence
## gives it, between the laid cards and the hand.
const SLIP_AT: Vector2 = Vector2(790, 520)
## The bowl lands beside the slip, in the open table between it and the ledger, so the
## claims stay readable while their dice roll.
const BOWL_AT: Vector2 = Vector2(1312, 575)
## Seconds the ledger waits after the total lands, while it flies over, and the least the
## table waits on a total once its sequence is done.
const FLIGHT: float = 0.35
const MIN_READ: float = 0.05
## The kitty lies face up this long before the landlord takes it, and where it is
## dealt from and labelled.
const KITTY_SHOW: float = 0.9
const KITTY_MARGIN: float = 0.12
const KITTY_FROM: Vector2 = Vector2(790, 200)
const KITTY_LABEL_AT: Vector2 = Vector2(790, 420)
const HAND_AT: Vector2 = Vector2(628, 940)
## Shake from a play landing, per card, and the most a plain play gives.
const THUMP_PER_CARD: float = 0.025
const THUMP_MAX: float = 0.2
const TAKEOVER_SHAKE: float = 0.45

var callout: Callout = Callout.new()
var tally: ScoreTally = ScoreTally.new()
var sequence: ScoreSequence = ScoreSequence.new()
var slip: AuditSlip = AuditSlip.new()
var dice: DiceBowl = DiceBowl.new()
var fx: TableFx = TableFx.new()
## The bar the Quota and meters are shown on, when the table has one.
var hud: TableHud = null
## The run, for the kitty's cards, which the round names by slot alone.
var controller: RunController = null
## A seat an Anonymous Letter makes pass next: its pass is tagged as forced.
var forced_seat: int = Seats.NONE

var _ledger: Ledger
var _pile: TrickPile
var _motion: TableMotion
var _player: EventPlayer
var _seats: Dictionary[int, SeatPanel] = {}
var _names: Dictionary[int, String] = {}
var _faces: Dictionary[int, Texture2D] = {}
var _landlord: int = Seats.NONE
## The seat holding the landlord bid, and each seat's last bid as a string key.
var _holder: int = Seats.NONE
var _bids: Dictionary[int, String] = {}
## The seat whose score the tally is counting.
var _scoring: int = Seats.NONE
var _target: float = 0.0
var _kitty_label: Label = Label.new()
var _kitty: Tween = null
## The audit rolls of the split under way, until every claim has rolled, and the tween
## that runs the dice moment.
var _rolls: Array[RunEvent] = []
var _dice_beat: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for layer: Control in [slip, tally, dice, fx, callout]:
		add_child(layer)
	for layer: Control in [dice, fx, callout]:
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slip.center = SLIP_AT
	dice.center = BOWL_AT
	_kitty_label.text = tr("keyword.kitty.name").to_upper()
	_kitty_label.theme_type_variation = CommonsTheme.TITLE
	_kitty_label.add_theme_font_size_override("font_size", TextSize.px(34))
	_kitty_label.add_theme_color_override("font_color", ScreenKit.STYLE.paper_bright)
	_kitty_label.add_theme_color_override("font_outline_color", ScreenKit.INK)
	_kitty_label.add_theme_constant_override("outline_size", 10)
	_kitty_label.visible = false
	add_child(_kitty_label)
	move_child(_kitty_label, 0)
	add_child(sequence)
	sequence.tally = tally
	sequence.fx = fx
	tally.resized.connect(sequence.place)
	tally.landed.connect(_on_landed)


func setup(
	ledger: Ledger,
	pile: TrickPile,
	motion: TableMotion,
	player: EventPlayer,
	seat_panels: Dictionary[int, SeatPanel],
	seat_names: Dictionary[int, String],
	faces: Dictionary[int, Texture2D]
) -> void:
	_ledger = ledger
	_pile = pile
	_motion = motion
	_player = player
	_seats = seat_panels
	_names = seat_names
	_faces = faces
	slip.setup(seat_names)
	pile.landed.connect(_on_cards_landed)
	sequence.pile = pile
	sequence.hurried.connect(ledger.hurry)
	player.waits_on = sequence.is_running


## Acts out event. quiet keeps the bookkeeping and drops the show, for replays.
func on_event(event: RunEvent, quiet: bool = false) -> void:
	# A skip plays the rest at once, so a dice moment under way is taken down.
	if quiet and (dice.is_showing() or not _rolls.is_empty()):
		_end_dice()
	match event.type:
		RunEvent.Type.SET_STARTED, RunEvent.Type.DEALT:
			if event.type == RunEvent.Type.SET_STARTED:
				_target = event.amount
				if hud != null and not quiet:
					hud.start_quota(_target)
			_holder = Seats.NONE
			_landlord = Seats.NONE
			_bids.clear()
			slip.clear()
			_clear_tally()
			callout.dismiss()
			_end_dice()
			_kitty_label.visible = false
		RunEvent.Type.BID:
			_on_bid(event.seat, event.value == 1, quiet)
		RunEvent.Type.LANDLORD_CHOSEN:
			_bids.clear()
		RunEvent.Type.ROUND:
			_on_round_event(event.round_event, quiet)
		RunEvent.Type.PLAY_SCORED:
			_on_scored(event, quiet)
		RunEvent.Type.NEED_DECLARED:
			if not quiet:
				_clear_tally()
				slip.claim(event.seat, event.value)
		RunEvent.Type.AUDIT_ROLLED:
			if not quiet:
				_on_rolled(event)
		RunEvent.Type.AUDITED:
			slip.set_verdict(event.seat, event.value == 1)
		RunEvent.Type.SHARE_PAID:
			if not quiet:
				slip.pay(event.seat, event.value)
				if event.seat == Seats.PLAYER:
					_gain(float(event.value), SLIP_AT)
		RunEvent.Type.BANKED:
			if not quiet and event.seat == Seats.PLAYER:
				_gain(event.amount, _ledger.amount_center(Seats.PLAYER))
		RunEvent.Type.METER_CHANGED:
			if hud != null and not quiet:
				hud.nudge_meter(event.text, event.value)
		RunEvent.Type.SET_ENDED:
			if not quiet:
				_on_set_ended(event.value == 1, event.amount)


## The villagers' seats and every seat's name, for the moments played beside these.
func seats() -> Dictionary[int, SeatPanel]:
	return _seats


func names() -> Dictionary[int, String]:
	return _names


## What a seat last did in the bidding, as a string key, or "" outside it.
func bid_key(seat: int) -> String:
	return _bids.get(seat, "")


func _on_bid(seat: int, claim: bool, quiet: bool) -> void:
	var key: String = "pass"
	if claim:
		key = "call" if _holder == Seats.NONE else "grab"
		_holder = seat
	_bids[seat] = "bid." + key
	if _seats.has(seat):
		_seats[seat].set_bid(tr("bid." + key))
		if not quiet:
			_seats[seat].bump()
	if quiet or not claim:
		return
	var who: String = "you" if seat == Seats.PLAYER else "sub"
	var line: String = tr("callout.%s.%s" % [key, who]).format({"name": _names.get(seat, "")})
	_shout(tr("callout." + key), Callout.Tier.CUT_IN, ScreenKit.RED, line, seat)


func _on_round_event(event: RoundEvent, quiet: bool) -> void:
	match event.type:
		RoundEvent.Type.ROUND_STARTED:
			_landlord = event.seat
		RoundEvent.Type.KITTY_TAKEN:
			if not quiet:
				_show_kitty(event.seat, event.card_ids)
		RoundEvent.Type.PASSED:
			var forced: bool = event.seat == forced_seat
			forced_seat = Seats.NONE
			if not quiet and _seats.has(event.seat):
				_seats[event.seat].flash(tr("campaign.forced" if forced else "stamp.pass"))
		RoundEvent.Type.PLAYED:
			# The last score's tally gives way to the next play's cards.
			if not sequence.is_running():
				_clear_tally()
			var type: Pattern.Type = event.pattern.type
			if quiet or (type != Pattern.Type.BOMB and type != Pattern.Type.ROCKET):
				return
			var word: String = "callout.rocket" if type == Pattern.Type.ROCKET else "callout.bomb"
			var who: String = _names.get(event.seat, "")
			_shout(tr(word), Callout.Tier.TAKEOVER, ScreenKit.RED, who, event.seat)
		RoundEvent.Type.ROUND_ENDED:
			if quiet:
				return
			_clear_tally()
			var landlord_won: bool = event.seat == _landlord
			var player_won: bool = landlord_won == (_landlord == Seats.PLAYER)
			var line: String = tr("banner.landlord_wins" if landlord_won else "banner.peasants_win")
			var cloth: Color = ScreenKit.RED if player_won else ScreenKit.LOSS
			var word: String = tr("callout.won" if player_won else "callout.lost")
			_shout(word, Callout.Tier.TAKEOVER, cloth, line, Seats.NONE)


## Acts a play's score out under the trick, then sends it to the ledger. The queue waits
## for the sequence and then for the total to be read; the ledger's own total rolls once
## the number arrives.
func _on_scored(event: RunEvent, quiet: bool) -> void:
	if quiet:
		sequence.stop()
		_ledger.add_play(event.seat, event.grain, event.rate, event.zeal, event.amount)
		return
	_scoring = event.seat
	var pace: float = (
		_pace() * (1.0 if event.seat == Seats.PLAYER else UiMotion.PRESETS.score_villager)
	)
	sequence.target = _target
	var seconds: float = sequence.play(event, pace)
	var flight: float = FLIGHT if seconds > 0.0 else 0.0
	_ledger.add_play(
		event.seat, event.grain, event.rate, event.zeal, event.amount, seconds + flight
	)
	if seconds > 0.0:
		_player.hold(maxf(ScoreTally.read_time(pace), MIN_READ))


func _on_landed(total_text: String) -> void:
	if _scoring == Seats.NONE or _ledger == null:
		return
	var to: Vector2 = _ledger.amount_center(_scoring)
	fx.fly("+" + total_text, tally.total_center(), to, Color(Keywords.INKS["grain"]))


## Work points reach the player: the number flies to the Quota bar, which fills as it
## lands.
func _gain(amount: float, from: Vector2) -> void:
	if hud == null or amount <= 0.0:
		return
	fx.fly("+" + Strings.score(amount), from, hud.progress_center(), Color(Keywords.INKS["grain"]))
	hud.add_progress(amount, TableFx.FLY_TIME)


## The Quota is met or missed across the whole screen, before the table is left, in the
## words the bar shows its figures in (ADR 0022).
func _on_set_ended(met: bool, progress: float) -> void:
	slip.clear()
	var line: String = tr("callout.quota.sub").format(
		{"progress": Strings.score(progress), "target": Strings.score(_target)}
	)
	if hud != null:
		var shown: String = hud.end_line(progress, _target)
		line = line if shown.is_empty() else shown
		met = ShownFigures.reads_met(met)
	var word: String = tr("callout.quota.met" if met else "callout.quota.missed")
	Audio.play(AudioEvents.QUOTA_MET if met else AudioEvents.QUOTA_MISSED)
	_shout(word, Callout.Tier.TAKEOVER, ScreenKit.RED if met else ScreenKit.LOSS, line, Seats.NONE)


## Every claim's audit roll arrives together. Once each claim on the slip has rolled, the
## bowl drops in and all the dice are thrown at once; when they settle, each audited
## seat is called out and the rest are marked not audited, then the bowl lifts away. The
## queue waits for all of it.
func _on_rolled(event: RunEvent) -> void:
	_rolls.append(event)
	if _rolls.size() < slip.claim_count():
		return
	var rolled_seats: Array[int] = []
	var faces: Array[int] = []
	var rolled_names: Array[String] = []
	for roll: RunEvent in _rolls:
		rolled_seats.append(roll.seat)
		faces.append(roll.value)
		rolled_names.append(_names.get(roll.seat, ""))
	var audit_faces: int = roundi(_rolls[0].amount)
	_rolls.clear()
	_kill_dice_beat()
	var seconds: float = dice.roll(rolled_seats, faces, audit_faces, rolled_names)
	Audio.play(AudioEvents.DICE_ROLL)
	_dice_beat = create_tween()
	_dice_beat.tween_interval(seconds)
	_dice_beat.tween_callback(_mark_unchecked.bind(rolled_seats, faces, audit_faces))
	var cut_in: float = Callout.seconds_for(Callout.Tier.CUT_IN)
	for seat: int in dice.audited_seats():
		_dice_beat.tween_callback(_call_audit.bind(seat))
		_dice_beat.tween_interval(cut_in)
		seconds += cut_in
	_dice_beat.tween_callback(dice.lift_away)
	_dice_beat.tween_callback(Audio.fill.bind(AudioEvents.MOTION_SETTLE))
	_player.hold(seconds + DiceBowl.lift_seconds())


func _mark_unchecked(rolled_seats: Array[int], faces: Array[int], audit_faces: int) -> void:
	for index: int in rolled_seats.size():
		if faces[index] > audit_faces:
			slip.mark_unchecked(rolled_seats[index])


func _call_audit(seat: int) -> void:
	_shout(tr("callout.audit"), Callout.Tier.CUT_IN, ScreenKit.RED, _names.get(seat, ""), seat)


## Takes the dice moment down at once, with nothing of it left running.
func _end_dice() -> void:
	_rolls.clear()
	_kill_dice_beat()
	dice.dismiss()


func _kill_dice_beat() -> void:
	UiMotion.end(_dice_beat)
	_dice_beat = null


## The kitty is dealt face up in the middle for everyone to see, then goes to the
## landlord.
func _show_kitty(seat: int, card_ids: Array[int]) -> void:
	var cards: Array[CardInstance] = []
	for card_id: int in card_ids:
		if card_id < Deck.SIZE:
			cards.append(controller.table.deck_card(card_id))
	if cards.is_empty() or _player.step <= 0.0:
		return
	_pile.clear()
	# The kitty's wild cards are wild only when they go to you (ADR 0039).
	_pile.show_play(cards, KITTY_FROM, [], null, seat == Seats.PLAYER)
	_kitty_label.reset_size()
	_kitty_label.position = KITTY_LABEL_AT - _kitty_label.size / 2.0
	_kitty_label.visible = true
	UiMotion.stamp(_kitty_label)
	var to: Vector2 = HAND_AT
	if _seats.has(seat):
		to = _seats[seat].global_position + _seats[seat].size / 2.0
	UiMotion.end(_kitty)
	_kitty = create_tween()
	_kitty.tween_interval(KITTY_SHOW)
	_kitty.tween_callback(_pile.sweep.bind(to))
	_kitty.tween_callback(_kitty_label.hide)
	# A little past the sweep, so the landlord's first play never lands under it.
	_player.hold(KITTY_SHOW + UiMotion.PRESETS.sweep + KITTY_MARGIN)


## Shakes the table a little, for a beat played on it.
func bump(trauma: float) -> void:
	_motion.bump(trauma)


## A play lands with a thump that grows with its size.
func _on_cards_landed(count: int) -> void:
	_motion.bump(minf(THUMP_MAX, THUMP_PER_CARD * count))


func _shout(word: String, tier: Callout.Tier, cloth: Color, line: String, seat: int) -> void:
	var face: Texture2D = _faces.get(seat)
	var seconds: float = callout.shout(word, tier, cloth, line, face, seat != Seats.RIGHT)
	# A banner sweeps in with a brush stroke, unless its event already sounds.
	Audio.fill(AudioEvents.CALLOUT_CUT)
	if tier == Callout.Tier.TAKEOVER:
		_motion.bump(TAKEOVER_SHAKE)
	_player.hold(seconds)


## The table's speed against the default, so a faster table shortens every beat.
func _pace() -> float:
	return _player.step / UiMotion.PRESETS.event_step


## The tally and the sequence acting on it are taken down.
func _clear_tally() -> void:
	sequence.stop()
	tally.clear()
