class_name RunStakes
extends RefCounted
## What a stake changes (ADR 0025, "Stakes"): only numbers the game already has, each
## handed to the run as its own copy, never by changing a shared Resource. A stake keeps
## every rule of the stakes below it, so its numbers are the sum of its own and theirs.

const STAKES: StakeList = preload("res://data/run/stakes/stakes.tres")
const PERCENT: int = 100


## The highest stake there is.
static func last(list: StakeList = STAKES) -> int:
	return list.stakes.size() - 1


## The stake's numbers with every lower stake's added in, as a new StakeDef. A stake
## past the last counts as the last.
static func total(stake: int, list: StakeList = STAKES) -> StakeDef:
	var sum: StakeDef = StakeDef.new()
	for index: int in mini(stake, last(list)) + 1:
		var step: StakeDef = list.stakes[index]
		sum.target_percent += step.target_percent
		sum.store_slot_cut += step.store_slot_cut
		sum.famine += step.famine
		sum.denunciation += step.denunciation
		sum.audit_faces += step.audit_faces
		sum.ladder_severity += step.ladder_severity
	return sum


## A counter's copy with the stake's slots taken off, and only the envelopes given.
static func shop(params: ShopParams, cut: int, envelopes: Array[EnvelopeDef]) -> ShopParams:
	var copy: ShopParams = params.duplicate()
	copy.slots = maxi(params.slots - cut, 0)
	copy.envelopes = envelopes
	return copy


## The audit's copy with more base faces; NeedAudit still caps them at max_faces.
static func audit(params: AuditParams, sum: StakeDef) -> AuditParams:
	var copy: AuditParams = params.duplicate()
	copy.base_faces = params.base_faces + sum.audit_faces
	return copy


## The ladder's copy with every Set type's budget raised.
static func ladder(params: LadderParams, sum: StakeDef) -> LadderParams:
	var copy: LadderParams = params.duplicate()
	var budgets: Array[int] = []
	for budget: int in params.severity_budgets:
		budgets.append(budget + sum.ladder_severity)
	copy.severity_budgets = budgets
	return copy


## The Sets' copy with every target raised by the stake's percent.
static func sets(params: SetParams, sum: StakeDef) -> SetParams:
	var copy: SetParams = params.duplicate()
	var targets: Array[float] = []
	for target: float in params.targets:
		targets.append(target * (PERCENT + sum.target_percent) / PERCENT)
	copy.targets = targets
	return copy
