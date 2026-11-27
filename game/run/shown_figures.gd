class_name ShownFigures
extends RefCounted
## How every screen shows the run's figures (ADR 0022): the one place that decides it.
## A figure is shown as it is, unless it went dark or the stage is past the last.
##
## - A dark figure, a meter or the norm the household reported lower, is shown as "None
##   reported" for the rest of the run. Nothing warns of it: no pulse, no sound, no
##   dread on the board. The true figure goes on counting, and a setback or a death it
##   brings still comes. A dark norm hides the Quota's target; the progress still shows.
## - At the stage past the last (ArtStages.FILED_STAGE) every figure reads as a success:
##   the Quota as fulfilled, every meter as "None reported", coupons as ample. The true
##   figures are only on the small ledger, which shows them as the stages before it do.
## A run with no dark figure, below that stage, shows every figure as it is.

const NONE_REPORTED: String = "figure.none_reported"
const AMPLE: String = "figure.coupons.ample"
const FULFILLED: String = "figure.quota.fulfilled"
const QUOTA: String = "table.quota"
const QUOTA_DARK: String = "table.quota.dark"


## True at the stage past the last, where every figure reads as a success.
static func all_success() -> bool:
	return ArtStages.past_last()


## True when the screens show figure as it truly is. Only then may a change to it be
## signalled: a pulse, a sound, a band, the board's dread.
static func is_true(state: RunView, figure: String) -> bool:
	return not all_success() and not is_dark(state, figure)


## True when figure went dark in this run, whatever the stage.
static func is_dark(state: RunView, figure: String) -> bool:
	return state.is_dark(figure)


## What the board's dread reads for a meter: its value while it is shown, else none.
static func board(state: RunView, figure: String, value: int) -> int:
	return value if is_true(state, figure) else 0


## A meter's or the norm's value as text: the number, or "None reported".
static func meter(state: RunView, figure: String, value: int) -> String:
	return str(value) if is_true(state, figure) else none_reported()


## Coupons as text through a count key: the count, or ample at the stage past the last.
## Coupons never go dark.
static func coupons(amount: int, key: String) -> String:
	if all_success():
		return TranslationServer.translate(AMPLE)
	return Strings.count(key, amount)


## True when the Quota's target is shown.
static func shows_target(state: RunView) -> bool:
	return is_true(state, RunCorrections.NORM)


## The Quota's progress against its target as the bar writes it: both, the progress
## alone beside "None reported" under a dark norm, or fulfilled at the last stage.
static func quota(state: RunView, progress: float, target: float) -> String:
	if all_success():
		return TranslationServer.translate(FULFILLED)
	if not shows_target(state):
		return TranslationServer.translate(QUOTA_DARK).format({"progress": Strings.score(progress)})
	return TranslationServer.translate(QUOTA).format(
		{"progress": Strings.score(progress), "target": Strings.score(target)}
	)


## True when the Quota is to read as met: when it is, or at the stage past the last.
static func reads_met(met: bool) -> bool:
	return met or all_success()


## A figure's text for a stat tile, or "" when its number is shown as it is.
static func tile_text(state: RunView, figure: String) -> String:
	if is_true(state, figure):
		return ""
	match figure:
		RunCorrections.COUPONS:
			return TranslationServer.translate(AMPLE)
		RunCorrections.PROGRESS:
			return TranslationServer.translate(FULFILLED)
	return none_reported()


## A meter's value as the small ledger writes it at the stage past the last: as the
## stages before it show it, the number or, for a dark one, "None reported".
static func ledger_meter(state: RunView, figure: String, value: int) -> String:
	return none_reported() if is_dark(state, figure) else str(value)


## The Quota as the small ledger writes it: progress and target, or the progress alone
## under a dark norm.
static func ledger_quota(state: RunView, progress: float, target: float) -> String:
	if is_dark(state, RunCorrections.NORM):
		return TranslationServer.translate(QUOTA_DARK).format({"progress": Strings.score(progress)})
	return TranslationServer.translate(QUOTA).format(
		{"progress": Strings.score(progress), "target": Strings.score(target)}
	)


static func none_reported() -> String:
	return TranslationServer.translate(NONE_REPORTED)
