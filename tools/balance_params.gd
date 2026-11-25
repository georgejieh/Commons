class_name BalanceParams
extends Resource
## The numbers in ADR 0027's strategy table, and the harness's own limits. The defaults
## here are the values the harness plays by; tools/balance_params.tres, which it loads,
## carries only a value that differs. Nothing in the game reads it.

## Coupons the mixed player keeps back at the state store: none, as ADR 0027 has it.
@export var kept_back: int = 0
## The mixed player buys at the black market only while Resentment is under this.
@export var resentment_limit: int = 40
## How much more than the true need the mixed player claims, in percent, while no more
## than over_claim_faces faces of the audit die audit.
@export var over_claim_percent: int = 50
@export var over_claim_faces: int = 1
## Campaigns collective and mixed never use.
@export var shunned_campaigns: Array[String] = ["anonymous_letter", "seizure_notice"]
## Campaigns whose chosen cards leave the hand take the lowest cards; every other
## Campaign that asks for cards takes the highest.
@export var giving_campaigns: Array[String] = ["mutual_aid"]
## ADR 0032's collective Campaigns are used only when they help: Relief Grain once
## Famine stands at this or more, Self-Criticism once Resentment does, and never when its
## Denunciation would reach the meter's death.
@export var relief_famine_at: int = 6
@export var criticism_resentment_at: int = 6
## Commands one run may send before it fails as stuck.
@export var max_commands: int = 50000
## The run's start time, fixed so the run's ID, and so the run, is the same each time.
@export var start_time: int = 1_763_200_000
## The household every run starts as.
@export var household: String = "poor_peasants"
