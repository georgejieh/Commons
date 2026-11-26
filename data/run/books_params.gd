class_name BooksParams
extends Resource
## The books' numbers (ADR 0022): how far figures reported from outside the game
## may raise the norm and the shops' prices over one run, what the field of each figure
## can hold, and what each entry in the family's file costs every later run.

## The most corrections can raise every later Quota's target over a run, in percent of
## the target before them: 900 is ten times. With the file's double and the norm's own
## steps every target stays far inside what a score can hold (Scorer.MAX_SCORE).
@export var norm_cap_percent: int = 900
## The most corrections can raise both shops' prices over a run, in percent: ten times.
@export var price_cap_percent: int = 900
## The most coupons a figure can report: what the field holds, so a larger report is
## clamped to it: six digits.
@export var coupons_max: int = 999_999
## The most overfulfilment steps the norm figure can report.
@export var norm_steps_max: int = 999
## Every run starts with its targets raised this many percent of their base for each
## entry in the family's file, up to entry_cap_percent: 10 an entry, up to double.
@export var entry_percent: int = 10
## The most the entries can raise a run's targets, in percent of their base.
@export var entry_cap_percent: int = 100
## The corruption each entry adds when it is written (ADR 0018), before the growth that
## makes every act cost more as corruption rises (CorruptionParams.growth).
@export var entry_corruption: float = 5.0
