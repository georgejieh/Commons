class_name CorruptionParams
extends Resource
## The hidden corruption's numbers (ADR 0018, ADR 0025): each event's weight, how fast
## the same act costs more as corruption grows, and what counts as holding a surplus.
## Each event is an attribution rule: the game counts the circumstance, and does not claim
## to prove the cause.

## Weight by event ID (CorruptionEvents names them).
@export var weights: Dictionary[String, float] = {}
## Each event adds weight * (1 + growth * corruption / 100), corruption as it stands.
@export var growth: float = 3.0
## A family starving counts while the player holds at least this many coupons.
@export var coupon_threshold: int = 8
## The Campaigns whose use counts: the two hostile ones.
@export var hostile_campaigns: Array[String] = []


func weight(event_id: String) -> float:
	return weights.get(event_id, 0.0)
