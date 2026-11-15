class_name RunUnlocks
extends RefCounted
## Which content a run may be offered (ADR 0025, "Unlocks"). An item is open when its
## unlock tier is at or below the finished runs the run started from, saved in its
## identity, so a loaded save opens the same items. A run that is not a full run, such as
## the demo, has every tier open. This decides eligibility only: definitions are still
## looked up by ID from the whole pools, so an item already held always works. Debuffs
## have no tier.

## Past every tier an item can carry: everything is open.
const ALL_OPEN: int = 1 << 30


## The highest tier open to the run.
static func open_tier(identity: RunIdentity) -> int:
	return identity.finished_runs if identity.is_full() else ALL_OPEN


static func is_open(unlock_tier: int, open: int) -> bool:
	return unlock_tier <= open


## Finished runs still needed before a tier opens, 0 once it is open.
static func runs_left(unlock_tier: int, finished_runs: int) -> int:
	return maxi(unlock_tier - finished_runs, 0)


static func cadres(pool: Array[ModifierDef], open: int) -> Array[ModifierDef]:
	return pool.filter(func(item: ModifierDef) -> bool: return item.unlock_tier <= open)


static func campaigns(pool: Array[CampaignDef], open: int) -> Array[CampaignDef]:
	return pool.filter(func(item: CampaignDef) -> bool: return item.unlock_tier <= open)


static func directives(pool: Array[DirectiveDef], open: int) -> Array[DirectiveDef]:
	return pool.filter(func(item: DirectiveDef) -> bool: return item.unlock_tier <= open)


static func reforms(pool: Array[ReformDef], open: int) -> Array[ReformDef]:
	return pool.filter(func(item: ReformDef) -> bool: return item.unlock_tier <= open)


static func envelopes(pool: Array[EnvelopeDef], open: int) -> Array[EnvelopeDef]:
	return pool.filter(func(item: EnvelopeDef) -> bool: return item.unlock_tier <= open)
