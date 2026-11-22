class_name MotionPresets
extends Resource
## Every duration and easing the table's motion uses (P3B.6). Reduced motion scales
## durations by reduced_scale and turns shake and hit-stop off.

## Seconds between table events, so each bot play can be seen.
@export var event_step: float = 0.55
## The arrival plays the table this much slower: everything on it is new to the player.
@export var arrival_scale: float = 1.5
@export var deal: float = 0.25
@export var hover: float = 0.12
@export var select: float = 0.1
@export var play: float = 0.22
## A villager's seat swells to wind_scale over wind_up seconds before its cards leave it.
## The player did not choose that play, so they get a beat to look. Their own play
## answers at once.
@export var wind_up: float = 0.16
@export var wind_scale: float = 1.04
@export var sweep: float = 0.3
## A won trick leaves the table with this Tween.TransitionType and Tween.EaseType.
@export var sweep_transition: int = Tween.TRANS_CUBIC
@export var sweep_ease: int = Tween.EASE_IN
@export var count_up: float = 0.45
## Tween.TransitionType and Tween.EaseType for every move.
@export var transition: int = Tween.TRANS_CUBIC
@export var ease: int = Tween.EASE_OUT
## Screen shake: trauma added per bomb, lost per second, and the offset at full trauma.
@export var bomb_trauma: float = 0.6
@export var trauma_decay: float = 1.6
@export var max_shake: float = 18.0
## How fast the shake wobbles on each axis, in radians per second.
@export var shake_speed: Vector2 = Vector2(47.0, 53.0)
## Seconds the game holds still when a bomb lands.
@export var hit_stop: float = 0.08
## Hover lift and tilt for a card under the cursor, in pixels and radians.
@export var hover_lift: float = 14.0
@export var max_tilt: float = 0.12
## Duration multiplier under reduced motion.
@export var reduced_scale: float = 0.35

@export_group("Interface")
## A button's scale on hover and while pressed.
@export var hover_scale: float = 1.04
@export var press_scale: float = 0.96
@export var hover_time: float = 0.16
## A screen's pieces fade and settle in one after another, each over enter_time and
## enter_stagger apart. A page of many pieces closes the gap up so that the last one is
## in by enter_within.
@export var enter_time: float = 0.5
@export var enter_stagger: float = 0.08
@export var enter_within: float = 1.1
## Numbers roll to their new value over this long.
@export var count_time: float = 0.6
## A stamp lands from this scale and tilt.
@export var stamp_from_scale: float = 1.6
@export var stamp_tilt: float = -0.12
@export var stamp_time: float = 0.22
## A played card flies from its seat to its lane.
@export var fly_time: float = 0.28
## Cards in a fresh deal arrive one after another.
@export var deal_stagger: float = 0.03
## A banner stays up this long.
@export var banner_hold: float = 1.1
## Screen changes cross through an ink wipe this long.
@export var wipe_time: float = 0.22
## Each epilogue line arrives this long after the one before (ADR 0024).
@export var epilogue_beat: float = 0.45

@export_group("Title")
## The title's first piece starts this long after the screen opens, and each piece after
## the name follows the one before by title_stagger.
@export var title_start: float = 0.1
@export var title_stagger: float = 0.12
## The name is pressed a letter at a time: each from letter_from_scale over letter_time,
## letter_stagger after the one before.
@export var letter_stagger: float = 0.06
@export var letter_time: float = 0.36
@export var letter_from_scale: float = 1.22
## The poster behind the title is laid down from this scale over this long.
@export var settle_from: float = 1.04
@export var settle_time: float = 1.6
