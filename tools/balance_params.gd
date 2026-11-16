class_name BalanceParams
extends Resource
## The numbers in ADR 0027's strategy table, and the harness's own limits. The harness
## loads tools/balance_params.tres; nothing in the game reads it.

## Coupons the mixed player keeps back at the state store.
@export var kept_back: int = 4
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
## Commands one run may send before it fails as stuck.
@export var max_commands: int = 50000
## The run's start time, fixed so the run's ID, and so the run, is the same each time.
@export var start_time: int = 1_763_200_000
## The household every run starts as.
@export var household: String = "poor_peasants"
