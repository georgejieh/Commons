class_name MotionPresets
extends Resource
## Every duration and easing the table's motion uses (P3B.6). Reduced motion scales
## durations by reduced_scale and turns shake and hit-stop off.

## Seconds between table events, so each bot play can be seen.
@export var event_step: float = 0.55
@export var deal: float = 0.25
@export var hover: float = 0.12
@export var select: float = 0.1
@export var play: float = 0.22
@export var sweep: float = 0.3
@export var count_up: float = 0.45
## Tween.TransitionType and Tween.EaseType for every move.
@export var transition: int = Tween.TRANS_CUBIC
@export var ease: int = Tween.EASE_OUT
## Screen shake: trauma added per bomb, lost per second, and the offset at full trauma.
@export var bomb_trauma: float = 0.6
@export var trauma_decay: float = 1.6
@export var max_shake: float = 18.0
## Seconds the game holds still when a bomb lands.
@export var hit_stop: float = 0.08
## Hover lift and tilt for a card under the cursor, in pixels and radians.
@export var hover_lift: float = 14.0
@export var max_tilt: float = 0.12
## Duration multiplier under reduced motion.
@export var reduced_scale: float = 0.35
