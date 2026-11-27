class_name RunUnlocks
extends RefCounted
## Which content a run may be offered (ADR 0025, "Unlocks"). An item is open when its
## unlock tier is at or below the finished runs the run started from, saved in its
## identity, so a loaded save opens the same items. A run that is not a full run, such as
## the demo, has every tier open below the wild ranks', so the demo stays as it was built
## (ADR 0029). This decides eligibility only: definitions are still looked up by ID from
## the whole pools, so an item already held always works. Debuffs have no tier.

## Past every tier an item can carry: everything is open.
const ALL_OPEN: int = 1 << 30
## The tier of the items that make ranks wild, the new mechanic of the fifth tier (ADR
## 0029). A run outside the profile stops below it.
const WILD_TIER: int = 4
## The last tier an item carries, the second content wave's (ADR 0032): open after five
## finished runs.
const LAST_TIER: int = 5


## The highest tier open to the run.
static func open_tier(identity: RunIdentity) -> int:
	return identity.finished_runs if identity.is_full() else WILD_TIER - 1


## Finished runs still needed before a tier opens, 0 once it is open.
static func runs_left(unlock_tier: int, finished_runs: int) -> int:
	return maxi(unlock_tier - finished_runs, 0)


## The pool's Cadres whose unlock tier is at or below open.
static func cadres(pool: Array[ModifierDef], open: int) -> Array[ModifierDef]:
	return pool.filter(func(item: ModifierDef) -> bool: return item.unlock_tier <= open)


## The pool's Campaigns whose unlock tier is at or below open.
static func campaigns(pool: Array[CampaignDef], open: int) -> Array[CampaignDef]:
	return pool.filter(func(item: CampaignDef) -> bool: return item.unlock_tier <= open)


## The pool's Directives whose unlock tier is at or below open.
static func directives(pool: Array[DirectiveDef], open: int) -> Array[DirectiveDef]:
	return pool.filter(func(item: DirectiveDef) -> bool: return item.unlock_tier <= open)


## The pool's Reforms whose unlock tier is at or below open.
static func reforms(pool: Array[ReformDef], open: int) -> Array[ReformDef]:
	return pool.filter(func(item: ReformDef) -> bool: return item.unlock_tier <= open)


## The pool's envelope kinds whose unlock tier is at or below open.
static func envelopes(pool: Array[EnvelopeDef], open: int) -> Array[EnvelopeDef]:
	return pool.filter(func(item: EnvelopeDef) -> bool: return item.unlock_tier <= open)
