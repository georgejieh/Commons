class_name ScoreSequence
extends Node
## A scored play acted out as a small counting-house slot machine (P5.2a, the owner's
## playtest of 2026-11-24): each scored card ticks on the pile as its Grain is counted,
## an abacus bead a step higher each time; the hand's Rate and the play's Zeal are stamped
## on; then every Cadre, card mark, level or debuff that changed the score fires in the
## order the engine applied it. What fired moves (a Cadre's card jiggles on the board and
## its count updates, a marked card flashes on the pile, the rules slip swells), a handbell
## sounds a step higher than the last, or a dull gong a step lower for a cut, its figure on
## the tally bumps to the new value, and a tag beside it says what it added. Coupons a
## Surplus card paid (ADR 0041) come last, a tag on the card with no figure of the
## tally's. Then the total rolls up a bead at a time and is stamped home, harder and with
## a shake of the tally for a play worth much of the Quota. The table's pace scales it, a
## villager's goes quicker, and a click or Enter hurries what is left. Reduced motion
## keeps every figure, tag and sound and drops the jiggle, flash, swell, bump and shake.
## The table's events wait for it (EventPlayer.waits_on). It keeps the tally inside the
## room the table gives it, clear of the laid cards, the hand and the seats, through all
## its motion.

## The sequence is hurried: anything timed to it goes speed times as fast from now.
signal hurried(speed: float)
## A beat of the sequence has begun: its ScoreBeats.Kind and the step it shows, or -1.
signal beat(kind: int, step_index: int)
signal finished

const PRESETS: MotionPresets = preload("res://data/ui/motion_presets.tres")
const LOSS: Color = Color("3a322b")
## How far above the first chime the Zeal's stamp is pitched, in semitones.
const ZEAL_LIFT: float = 5.0
## Room kept between the tally's motion and the laid cards, the hand and the column.
const GAP: float = 6.0
## The player's own seat, whose plays are never hurried for sitting out.
const OWN_SEAT: int = 0
## The share of its beat the total takes to roll up.
const ROLL_SHARE: float = 0.85

var tally: ScoreTally
var fx: TableFx
var pile: TrickPile
var board: NoticeBoard = null
var strip: DebuffStrip = null
var controller: RunController = null
## The Quota's target, for how hard a total lands.
var target: float = 0.0
## True while villagers' plays go by at the hurried pace, as while the player sits out.
var hurry_villagers: bool = false

var _tween: Tween = null
var _roll: Tween = null
var _event: RunEvent = null
var _steps: Array[ScoreStep] = []
var _beats: ScoreBeats = null
var _speed: float = 1.0
var _ticks: int = 0
var _chimes: int = 0
var _cuts: int = 0
var _beads: int = 0
var _bead_count: int = 0
## True while place() runs, since sizing the tally calls it again.
var _placing: bool = false


## What a step can point at on the table besides the pile: the Cadre board, the rules
## slip, and the run whose Cadre counts the board shows.
func attach(notice_board: NoticeBoard, rules: DebuffStrip, run: RunController) -> void:
	board = notice_board
	strip = rules
	controller = run


## Acts out a PLAY_SCORED event at pace, where 1 is the player's own play at Standard.
## Returns its seconds, or 0 when pace leaves nothing to act out.
func play(event: RunEvent, pace: float) -> float:
	stop()
	_event = event
	_steps = event.steps if not event.steps.is_empty() else ScoreSequence.plain_steps(event)
	tally.begin(event.zeal)
	_reserve()
	place()
	if pace <= 0.0:
		_show_at_once()
		return 0.0
	_ticks = 0
	_chimes = 0
	_cuts = 0
	_beads = 0
	_beats = ScoreBeats.lay_out(_steps, pace)
	_tween = create_tween()
	for index: int in _beats.kinds.size():
		_tween.tween_callback(_beat.bind(index))
		_tween.tween_interval(_beats.seconds[index])
	_tween.tween_callback(_done)
	_speed = 1.0
	if hurry_villagers and event.seat != OWN_SEAT:
		hurry()
	return _beats.total() / _speed


func is_running() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


## Plays what is left faster, by score_hurried of its time.
func hurry() -> void:
	if not is_running() or _speed > 1.0:
		return
	_speed = 1.0 / maxf(PRESETS.score_hurried, 0.01)
	for running: Tween in [_tween, _roll]:
		if running != null and running.is_valid():
			running.set_speed_scale(_speed)
	hurried.emit(_speed)


## The steps the sequence under way or last played acts out, for tests.
func steps() -> Array[ScoreStep]:
	return _steps


## Takes the sequence down at once, its tally with it.
func stop() -> void:
	for running: Tween in [_tween, _roll]:
		if running != null and running.is_valid():
			running.kill()
	_tween = null
	_roll = null


## A click or Enter on the table hurries a sequence under way, as motion.md asks of every
## moment a round shows.
func _unhandled_input(event: InputEvent) -> void:
	if not is_running():
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	var clicked: bool = mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if clicked or event.is_action_pressed("ui_accept"):
		hurry()
		get_viewport().set_input_as_handled()


## The room the tally keeps to on screen: under the lowest a laid card can reach, over the
## top of a lifted card in the hand, and between the pile's left edge and the column.
func room() -> Rect2:
	var top: float = pile.global_position.y + pile.reach_below() + GAP
	var lifted: float = HandView.LIFT + HandView.ARMED_LIFT
	var bottom: float = TableScreen.HAND_AT.position.y - lifted - GAP
	var left: float = pile.global_position.x
	var right: float = TableScreen.ACTIONS_AT.position.x - GAP
	return Rect2(left, top, right - left, bottom - top)


## Centres the tally in its room, smaller only if its motion would not fit there.
func place() -> void:
	if pile == null or _placing:
		return
	_placing = true
	var box: Rect2 = room()
	tally.scale = Vector2.ONE
	# A tally left wide by a long figure gives the room back.
	tally.reset_size()
	var natural: Vector2 = tally.get_combined_minimum_size()
	var reach: Vector2 = tally.reach()
	var fit: float = minf(
		1.0,
		minf(
			(box.size.x - 2.0 * reach.x) / maxf(natural.x, 1.0),
			(box.size.y - 2.0 * reach.y) / maxf(natural.y, 1.0)
		)
	)
	tally.scale = Vector2.ONE * fit
	var origin: Vector2 = tally.get_parent_control().global_position
	tally.position = box.get_center() - natural * fit / 2.0 - origin
	_placing = false


## Gives each chit room for every figure it will show, so nothing moves as they change.
func _reserve() -> void:
	var texts: Array[Array] = [[Strings.score(0.0)], [], [], [Strings.score(_event.amount)]]
	for step: ScoreStep in _steps:
		if step.figure < ScoreStep.Figure.TOTAL:
			texts[step.figure].append(_figure_text(step.figure, step.after))
	for index: int in texts.size():
		var each: Array[String] = []
		each.assign(texts[index])
		tally.reserve(index, each)


## A play with no recorded steps, such as one a test makes up, shown as its plain sum.
static func plain_steps(event: RunEvent) -> Array[ScoreStep]:
	var trail: Array[ScoreStep] = []
	trail.append(
		_made(ScoreStep.Figure.GRAIN, ScoreStep.Source.CARD, ScoreStep.Op.ADD, event.grain, 0.0)
	)
	trail.append(
		_made(ScoreStep.Figure.RATE, ScoreStep.Source.HAND, ScoreStep.Op.SET, event.rate, 0.0)
	)
	trail.append(_made(ScoreStep.Figure.ZEAL, ScoreStep.Source.START, ScoreStep.Op.SET, 1.0, 0.0))
	if not is_equal_approx(event.zeal, 1.0):
		trail.append(
			_made(
				ScoreStep.Figure.ZEAL,
				ScoreStep.Source.MODIFIER,
				ScoreStep.Op.ADD,
				event.zeal - 1.0,
				1.0
			)
		)
	var product: float = event.grain * event.rate * event.zeal
	if product > 0.0 and not is_equal_approx(product, event.amount):
		var share: float = event.amount / product
		trail.append(
			_made(
				ScoreStep.Figure.TOTAL, ScoreStep.Source.MODIFIER, ScoreStep.Op.MUL, share, product
			)
		)
	return trail


static func _made(
	figure: ScoreStep.Figure,
	source: ScoreStep.Source,
	op: ScoreStep.Op,
	value: float,
	before: float
) -> ScoreStep:
	return ScoreStep.new(figure, source, op, value, before, ScoreStep.applied(op, before, value))


## What a step added, in a few words, such as "+30 Grain" or "×1.5 Zeal".
static func tag_text(step: ScoreStep) -> String:
	var name_key: String = "tally.total"
	if step.figure == ScoreStep.Figure.COUPONS:
		name_key = "score.step.coupons" if step.value != 1.0 else "score.step.coupon"
	elif step.figure != ScoreStep.Figure.TOTAL:
		name_key = "keyword.%s.name" % ScoreTally.WORDS[step.figure]
	var name: String = TranslationServer.translate(name_key)
	var key: String = "score.step.set"
	var value: String = _figure_text(step.figure, step.after)
	if step.op == ScoreStep.Op.ADD:
		key = "score.step.add" if step.value >= 0.0 else "score.step.less"
		value = _figure_text(step.figure, absf(step.value))
	elif step.op == ScoreStep.Op.MUL and step.figure != ScoreStep.Figure.RATE:
		key = "score.step.times"
		value = Strings.factor(step.value)
	return TranslationServer.translate(key).format({"value": value, "figure": name})


static func _figure_text(figure: ScoreStep.Figure, value: float) -> String:
	if figure != ScoreStep.Figure.RATE and figure != ScoreStep.Figure.ZEAL:
		return Strings.score(value)
	return Strings.factor(value)


func _beat(index: int) -> void:
	var seconds: float = _beats.seconds[index]
	var at: int = _beats.step_index[index]
	beat.emit(_beats.kinds[index], at)
	match _beats.kinds[index]:
		ScoreBeats.Kind.ENTER:
			tally.figure(ScoreTally.GRAIN, Strings.score(0.0), false)
		ScoreBeats.Kind.TICK:
			var step: ScoreStep = _steps[at]
			tally.figure(ScoreTally.GRAIN, Strings.score(step.after), true)
			pile.tick_card(step.card_id, seconds)
			Audio.play(AudioEvents.SCORE_TICK, ScoreBeats.semitones(_ticks))
			_ticks += 1
		ScoreBeats.Kind.RATE:
			tally.figure(ScoreTally.RATE, Strings.factor(_steps[at].after), true)
			Audio.play(AudioEvents.SCORE_RATE)
		ScoreBeats.Kind.ZEAL:
			tally.figure(ScoreTally.ZEAL, Strings.factor(_steps[at].after), true)
			Audio.play(AudioEvents.SCORE_ZEAL, ZEAL_LIFT)
		ScoreBeats.Kind.STEP:
			_fire(_steps[at], seconds)
		ScoreBeats.Kind.ROLL:
			_start_roll(seconds)
		ScoreBeats.Kind.STAMP:
			_stamp()


## One thing that changed the score fires: it moves, its sound plays, its figure bumps and
## its tag shows beside it.
func _fire(step: ScoreStep, seconds: float) -> void:
	var around: Rect2 = _point_at(step, seconds)
	if step.figure == ScoreStep.Figure.TOTAL:
		var product: float = step.before
		tally.scaled(ScoreTally.scale_percent(1.0, 1.0, product, step.after))
	elif step.figure != ScoreStep.Figure.COUPONS:
		tally.figure(step.figure, _figure_text(step.figure, step.after), true)
	if not around.has_area():
		# A coupon has no chit of its own: its tag stands over the total's.
		var chit: Vector2 = tally.tile_center(mini(step.figure, ScoreStep.Figure.TOTAL))
		around = Rect2(chit - Vector2(1.0, tally.size.y * tally.scale.y / 2.0), Vector2(2.0, 2.0))
	fx.tag(ScoreSequence.tag_text(step), around, ScoreSequence.ink_of(step))
	if step.is_cut():
		Audio.play(AudioEvents.SCORE_CUT, -ScoreBeats.semitones(_cuts))
		_cuts += 1
	else:
		Audio.play(AudioEvents.SCORE_CHIME, ScoreBeats.semitones(_chimes))
		_chimes += 1


## The ink a step's tag is written in: its figure's, or dull for a cut.
static func ink_of(step: ScoreStep) -> Color:
	if step.is_cut():
		return LOSS
	if step.figure == ScoreStep.Figure.TOTAL:
		return ScoreTally.TOTAL_INK
	if step.figure == ScoreStep.Figure.COUPONS:
		return ScreenKit.COUPON
	return Color(Keywords.INKS[ScoreTally.WORDS[step.figure]])


## Moves what made a step and returns where it is on screen: a held Cadre's card on the
## board, a card on the pile, or the rules slip for a debuff or a boss. Empty when none
## is in view, as for a level, and then the tag stands over the tally's chit.
func _point_at(step: ScoreStep, seconds: float) -> Rect2:
	var around: Rect2 = Rect2()
	if step.modifier_kind == ModifierDef.Kind.CADRE and board != null and controller != null:
		around = board.jiggle(controller, step.source_id, seconds)
	if step.card_id >= 0:
		var card: Rect2 = pile.flash_card(step.card_id, seconds)
		if not around.has_area():
			around = card
	var ruled: bool = step.modifier_kind in [ModifierDef.Kind.DEBUFF, ModifierDef.Kind.BOSS_TWIST]
	if not around.has_area() and ruled and strip != null and strip.is_visible_in_tree():
		UiMotion.pulse(strip)
		around = strip.get_global_rect()
	return around


func _start_roll(seconds: float) -> void:
	var total: float = _event.amount
	tally.figure(ScoreTally.TOTAL, Strings.score(0.0), false)
	_beads = 0
	var each: float = 0.05
	_bead_count = clampi(roundi(seconds / each), PRESETS.score_least_beads, PRESETS.score_beads)
	_roll = create_tween()
	_roll.set_speed_scale(_speed)
	_roll.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	# Done a little before the stamp, so its last bead never lands on it.
	_roll.tween_method(_rolling.bind(total), 0.0, 1.0, seconds * ROLL_SHARE)


func _rolling(share: float, total: float) -> void:
	tally.figure(ScoreTally.TOTAL, Strings.score(total * share), false)
	while _beads < _bead_count and share >= float(_beads + 1) / _bead_count:
		Audio.play(AudioEvents.SCORE_ROLL, ScoreBeats.semitones(_beads))
		_beads += 1


## The total lands: a stamp, heavier for a play worth much of the Quota, and the tally
## shakes for it; then the table sends it to the ledger.
func _stamp() -> void:
	if _roll != null and _roll.is_valid():
		_roll.kill()
	_roll = null
	var total_text: String = Strings.score(_event.amount)
	tally.figure(ScoreTally.TOTAL, total_text, true, true)
	var share: float = _event.amount / target if target > 0.0 else 0.0
	var weight: float = clampf(share / maxf(PRESETS.score_heavy, 0.0001), 0.0, 1.0)
	var heavy: bool = weight >= 1.0
	Audio.play(AudioEvents.SCORE_LAND_HEAVY if heavy else AudioEvents.SCORE_LAND)
	tally.shake(PRESETS.score_shake * weight, PRESETS.score_stamp)
	tally.land(total_text)


func _done() -> void:
	_tween = null
	tally.fade_after(ScoreTally.LINGER)
	finished.emit()


func _show_at_once() -> void:
	for step: ScoreStep in _steps:
		if step.figure < ScoreStep.Figure.TOTAL:
			tally.figure(step.figure, _figure_text(step.figure, step.after), false)
		elif step.figure == ScoreStep.Figure.TOTAL:
			tally.scaled(ScoreTally.scale_percent(1.0, 1.0, step.before, step.after))
	var total_text: String = Strings.score(_event.amount)
	tally.figure(ScoreTally.TOTAL, total_text, false)
	tally.land(total_text)
	tally.fade_after(ScoreTally.LINGER)
