class_name MotionPresets
extends Resource
## Every duration and easing the table's motion uses. Reduced motion scales durations by
## reduced_scale and turns shake and hit-stop off.

## Seconds between table events, so each bot play can be seen.
@export var event_step: float = 0.55
## What the table's pace setting multiplies the step by: Slow, Standard, Fast. A slower
## table gives each villager's play longer to be read; nothing else changes.
@export var pace_scales: Array[float] = [1.4, 1.0, 0.7]
## The arrival plays the table this much slower: everything on it is new to the player.
@export var arrival_scale: float = 1.5
## Seconds for a card to rise or sink as it is selected or cleared.
@export var select: float = 0.1
## Seconds a villager's seat swells before its cards leave it. The player did not choose
## that play, so they get a beat to look. Their own play answers at once.
@export var wind_up: float = 0.16
## How far the seat swells, as a multiple of its size.
@export var wind_scale: float = 1.04
## Seconds for a won trick to leave the table.
@export var sweep: float = 0.3
## A finished round stays on the table, all of it in view, this many table steps once its
## last share is paid; then the last trick is swept off and the next hand is dealt.
@export var round_close_steps: float = 1.0
## Seconds the table holds after a round ends, so its banner can be read. The table's
## pace does not scale it.
@export var round_end_hold: float = 1.6
## While the player sits out a trick they cannot answer, the table's step, at whatever
## pace is chosen, is multiplied by this, so the villagers' plays go by faster.
@export var sit_out_scale: float = 0.4
## The curve a won trick leaves the table on.
@export var sweep_transition: Tween.TransitionType = Tween.TRANS_CUBIC
## How that curve eases in and out.
@export var sweep_ease: Tween.EaseType = Tween.EASE_IN
## The curve every card move follows.
@export var move_transition: Tween.TransitionType = Tween.TRANS_CUBIC
## How that curve eases in and out.
@export var move_ease: Tween.EaseType = Tween.EASE_OUT
## The screen shake a bomb adds, from 0 to 1.
@export var bomb_trauma: float = 0.6
## The shake lost each second, from 0 to 1.
@export var trauma_decay: float = 1.6
## The screen's offset at full shake, in pixels.
@export var max_shake: float = 18.0
## How fast the shake wobbles on each axis, in radians per second.
@export var shake_speed: Vector2 = Vector2(47.0, 53.0)
## Seconds the game holds still when a bomb lands.
@export var hit_stop: float = 0.08
## Duration multiplier under reduced motion.
@export var reduced_scale: float = 0.35

@export_group("Scoring")
## Seconds the chits take to come in at the start of a scored play. Every score time is
## at the Standard pace.
@export var score_enter: float = 0.08
## Seconds for the first card's tick.
@export var score_tick: float = 0.09
## The least a quickened tick takes, in seconds.
@export var score_least_tick: float = 0.035
## Seconds for the Rate and for the Zeal to land.
@export var score_land: float = 0.18
## Seconds for the first Cadre, mark, level or debuff that changed the score.
@export var score_step: float = 0.34
## The least a quickened step takes, in seconds.
@export var score_least_step: float = 0.14
## Each tick and each step after the first takes this share of the one before, so a long
## play or chain speeds up as it goes.
@export var score_quicken: float = 0.85
## Seconds for the total to roll up.
@export var score_roll: float = 0.4
## Seconds for the total's stamp to land.
@export var score_stamp: float = 0.2
## The whole sequence keeps within this many seconds, however long the play.
@export var score_most: float = 2.6
## A villager's play is acted out at this share of the player's own time.
@export var score_villager: float = 0.75
## The share of the time a hurried play takes, clicked through or while the player sits
## out.
@export var score_hurried: float = 0.3
## How much larger a chit lands, and swells as its figure changes, as a multiple of its
## size.
@export var score_chit_scale: float = 1.08
## How much larger the total lands, as a multiple of its size.
@export var score_total_scale: float = 1.12
## The most the tally shakes, in pixels, for a play worth score_heavy of the Quota's
## target or more.
@export var score_shake: float = 5.0
## The share of the Quota's target at which a play lands with the heavier stamp and the
## shake.
@export var score_heavy: float = 0.2
## Seconds the label of what a step added stands.
@export var score_label_time: float = 0.75
## How far that label rises as it fades, in pixels.
@export var score_label_rise: float = 16.0
## Semitones each tick and chime climbs over the first, in steps of the major pentatonic,
## so any run stays in G; past the last they hold. A cut falls by the same steps.
@export var score_scale_steps: Array[int] = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24]
## The total rolls up a bead at a time: this many beads at most.
@export var score_beads: int = 8
## The fewest beads a total rolls in.
@export var score_least_beads: int = 3

@export_group("Interface")
## A button's scale on hover, as a multiple of its size.
@export var hover_scale: float = 1.04
## A button's scale while pressed, as a multiple of its size.
@export var press_scale: float = 0.96
## Seconds for a button to reach its hover scale.
@export var hover_time: float = 0.16
## Seconds a screen's piece takes to fade and settle in.
@export var enter_time: float = 0.5
## Seconds between one piece and the next arriving.
@export var enter_stagger: float = 0.08
## A page of many pieces closes the gap up so that the last one is in by this many seconds.
@export var enter_within: float = 1.1
## Seconds for a number to roll to its new value.
@export var count_time: float = 0.6
## The scale a stamp lands from, as a multiple of its size.
@export var stamp_from_scale: float = 1.6
## The tilt a stamp lands from, in radians.
@export var stamp_tilt: float = -0.12
## Seconds for a stamp to land.
@export var stamp_time: float = 0.22
## Seconds after a counter's cards start to arrive that a Scarce stamp is pressed: they are
## in, there is a breath, then it lands.
@export var scarce_wait: float = 0.85
## Seconds for a played card to fly from its seat to its lane.
@export var fly_time: float = 0.28
## Seconds between one card of a fresh deal and the next.
@export var deal_stagger: float = 0.03
## Seconds an ink wipe takes to cross between screens.
@export var wipe_time: float = 0.22
## Seconds each epilogue line arrives after the one before (ADR 0024).
@export var epilogue_beat: float = 0.45

@export_group("Title")
## Seconds after the screen opens before the title's first piece starts.
@export var title_start: float = 0.1
## Seconds each piece after the name follows the one before.
@export var title_stagger: float = 0.12
## Seconds between one letter of the name being pressed and the next.
@export var letter_stagger: float = 0.06
## Seconds each letter takes to be pressed.
@export var letter_time: float = 0.36
## The scale a letter is pressed from, as a multiple of its size.
@export var letter_from_scale: float = 1.22
## The poster behind the title is laid down from this scale, as a multiple of its size.
@export var settle_from: float = 1.04
## Seconds the poster takes to settle.
@export var settle_time: float = 1.6
