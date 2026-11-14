class_name TableMoments
extends Control
## The table acted out, as one layer over the play area. Small beats stay where they
## happen: a pass is tagged on the seat that passed, a card lands with weight, a score
## is counted up in chits under the trick and flies to the ledger. Big beats take the
## whole screen for a moment through the Callout: a call or grab for the landlord
## seat, a bomb, the end of a round. It holds the event queue still for as long as
## each beat needs, and shows only what the run already says; the ledger, seats and
## meters hold the same facts at rest.

const GRAIN: Color = Color("8a5a12")
const LOSS: Color = Color("3a322b")
## Where the tally and the audit slip sit, as their middles.
const TALLY_AT: Vector2 = Vector2(790, 660)
const SLIP_AT: Vector2 = Vector2(790, 520)
## How fast a villager's score is counted, against the player's own at 1.
const VILLAGER_PACE: float = 0.55
## Seconds the ledger waits after the total lands, while it flies over.
const FLIGHT: float = 0.35
## The kitty lies face up this long before the landlord takes it, and where it is
## dealt from and labelled.
const KITTY_SHOW: float = 0.9
const KITTY_FROM: Vector2 = Vector2(790, 200)
const KITTY_LABEL_AT: Vector2 = Vector2(790, 420)
const HAND_AT: Vector2 = Vector2(660, 940)
## Shake from a play landing, per card, and the most a plain play gives.
const THUMP_PER_CARD: float = 0.025
const THUMP_MAX: float = 0.2
const TAKEOVER_SHAKE: float = 0.45

var callout: Callout = Callout.new()
var tally: ScoreTally = ScoreTally.new()
var slip: AuditSlip = AuditSlip.new()
var fx: TableFx = TableFx.new()
## The bar the Quota and meters are shown on, when the table has one.
var hud: TableHud = null

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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for layer: Control in [slip, tally, fx, callout]:
		add_child(layer)
	for layer: Control in [fx, callout]:
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slip.center = SLIP_AT
	_kitty_label.text = tr("keyword.kitty.name").to_upper()
	_kitty_label.theme_type_variation = CommonsTheme.TITLE
	_kitty_label.add_theme_font_size_override("font_size", 34)
	_kitty_label.add_theme_color_override("font_color", ScreenKit.STYLE.paper_bright)
	_kitty_label.add_theme_color_override("font_outline_color", ScreenKit.INK)
	_kitty_label.add_theme_constant_override("outline_size", 10)
	_kitty_label.visible = false
	add_child(_kitty_label)
	move_child(_kitty_label, 0)
	tally.resized.connect(_center_tally)
	tally.landed.connect(_on_landed)


func setup(
	ledger: Ledger,
	pile: TrickPile,
	motion: TableMotion,
	player: EventPlayer,
	seats: Dictionary[int, SeatPanel],
	names: Dictionary[int, String],
	faces: Dictionary[int, Texture2D]
) -> void:
	_ledger = ledger
	_pile = pile
	_motion = motion
	_player = player
	_seats = seats
	_names = names
	_faces = faces
	slip.setup(names)
	pile.landed.connect(_on_cards_landed)


## Acts out event. quiet keeps the bookkeeping and drops the show, for replays.
func on_event(event: RunEvent, quiet: bool = false) -> void:
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
			tally.clear()
			callout.dismiss()
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
				tally.clear()
				slip.claim(event.seat, event.value)
		RunEvent.Type.AUDITED:
			slip.audited(event.seat, event.value == 1)
		RunEvent.Type.SHARE_PAID:
			if not quiet:
				slip.paid(event.seat, event.value)
				if event.seat == 0:
					_gain(float(event.value), SLIP_AT)
		RunEvent.Type.BANKED:
			if not quiet and event.seat == 0:
				_gain(event.amount, _ledger.amount_center(0))
		RunEvent.Type.METER_CHANGED:
			if hud != null and not quiet:
				hud.nudge_meter(event.text, event.value)
		RunEvent.Type.SET_ENDED:
			if not quiet:
				_on_set_ended(event.value == 1, event.amount)


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
	var who: String = "you" if seat == 0 else "sub"
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
			if not quiet and _seats.has(event.seat):
				_seats[event.seat].flash(tr("stamp.pass"))
		RoundEvent.Type.PLAYED:
			var type: Pattern.Type = event.pattern.type
			if quiet or (type != Pattern.Type.BOMB and type != Pattern.Type.ROCKET):
				return
			var word: String = "callout.rocket" if type == Pattern.Type.ROCKET else "callout.bomb"
			var who: String = _names.get(event.seat, "")
			_shout(tr(word), Callout.Tier.TAKEOVER, ScreenKit.RED, who, event.seat)
		RoundEvent.Type.ROUND_ENDED:
			if quiet:
				return
			tally.clear()
			var landlord_won: bool = event.seat == _landlord
			var player_won: bool = landlord_won == (_landlord == 0)
			var line: String = tr("banner.landlord_wins" if landlord_won else "banner.peasants_win")
			var cloth: Color = ScreenKit.RED if player_won else LOSS
			var word: String = tr("callout.won" if player_won else "callout.lost")
			_shout(word, Callout.Tier.TAKEOVER, cloth, line, Seats.NONE)


## Counts a play's score up under the trick, then sends it to the ledger. The queue
## waits for the count; the ledger's own total rolls once the number arrives.
func _on_scored(event: RunEvent, quiet: bool) -> void:
	if quiet:
		_ledger.add_play(event.seat, event.grain, event.rate, event.zeal, event.amount)
		return
	_scoring = event.seat
	var pace: float = _pace() * (1.0 if event.seat == 0 else VILLAGER_PACE)
	_pile.pulse_top(ScoreTally.COUNT * pace)
	var seconds: float = tally.show_score(event.grain, event.rate, event.zeal, event.amount, pace)
	var flight: float = FLIGHT if seconds > 0.0 else 0.0
	_ledger.add_play(
		event.seat, event.grain, event.rate, event.zeal, event.amount, seconds + flight
	)
	_player.hold(seconds)


func _on_landed(total_text: String) -> void:
	if _scoring == Seats.NONE or _ledger == null:
		return
	fx.fly("+" + total_text, tally.total_center(), _ledger.amount_center(_scoring), GRAIN)


## Work points reach the player: the number flies to the Quota bar, which fills as it
## lands.
func _gain(amount: float, from: Vector2) -> void:
	if hud == null or amount <= 0.0:
		return
	fx.fly("+" + Strings.score(amount), from, hud.progress_center(), GRAIN)
	hud.add_progress(amount, TableFx.FLY_TIME)


## The Quota is met or missed across the whole screen, before the table is left.
func _on_set_ended(met: bool, progress: float) -> void:
	slip.clear()
	var line: String = tr("callout.quota.sub").format(
		{"progress": Strings.score(progress), "target": Strings.score(_target)}
	)
	var word: String = tr("callout.quota.met" if met else "callout.quota.missed")
	_shout(word, Callout.Tier.TAKEOVER, ScreenKit.RED if met else LOSS, line, Seats.NONE)


## The kitty is dealt face up in the middle for everyone to see, then goes to the
## landlord.
func _show_kitty(seat: int, card_ids: Array[int]) -> void:
	var cards: Array[CardInstance] = []
	for card_id: int in card_ids:
		if card_id < Deck.SIZE:
			cards.append(CardInstance.from_deck_id(card_id))
	if cards.is_empty() or _player.step <= 0.0:
		return
	_pile.clear()
	_pile.show_play(cards, KITTY_FROM)
	_kitty_label.reset_size()
	_kitty_label.position = KITTY_LABEL_AT - _kitty_label.size / 2.0
	_kitty_label.visible = true
	UiMotion.stamp(_kitty_label)
	var to: Vector2 = HAND_AT
	if _seats.has(seat):
		to = _seats[seat].global_position + _seats[seat].size / 2.0
	if _kitty != null and _kitty.is_valid():
		_kitty.kill()
	_kitty = create_tween()
	_kitty.tween_interval(KITTY_SHOW)
	_kitty.tween_callback(_pile.sweep.bind(to))
	_kitty.tween_callback(_kitty_label.hide)
	_player.hold(KITTY_SHOW + TableMotion.PRESETS.sweep)


## A play lands with a thump that grows with its size.
func _on_cards_landed(count: int) -> void:
	_motion.bump(minf(THUMP_MAX, THUMP_PER_CARD * count))


func _shout(word: String, tier: Callout.Tier, cloth: Color, line: String, seat: int) -> void:
	var face: Texture2D = _faces.get(seat)
	var seconds: float = callout.shout(word, tier, cloth, line, face, seat != 1)
	if tier == Callout.Tier.TAKEOVER:
		_motion.bump(TAKEOVER_SHAKE)
	_player.hold(seconds)


## The table's speed against the default, so a faster table shortens every beat.
func _pace() -> float:
	return _player.step / TableMotion.PRESETS.event_step


func _center_tally() -> void:
	tally.position = TALLY_AT - tally.size / 2.0
