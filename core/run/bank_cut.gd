class_name BankCut
extends RefCounted
## What debuffs take from what the player banks in one round (ADR 0023): Overtime voids
## it when their side lost, then Grain Tax takes a share, rounded against the player.
## Each cut that takes something is logged.

const PERCENT: float = 100.0

var voided: bool = false
var tax_percent: int = 0


func _init(voided_value: bool = false, tax_value: int = 0) -> void:
	voided = voided_value
	tax_percent = tax_value


## What is left of amount once the cuts are taken.
func apply(amount: float, player: int, events: Array[RunEvent]) -> float:
	var kept: float = amount
	if voided and kept > 0.0:
		events.append(RunEvent.new(RunEvent.Type.BANK_VOIDED, player, 0, kept))
		kept = 0.0
	if tax_percent > 0 and kept > 0.0:
		var taken: float = minf(ceilf(kept * tax_percent / PERCENT), kept)
		kept -= taken
		events.append(RunEvent.new(RunEvent.Type.GRAIN_TAXED, player, tax_percent, taken))
	return kept
