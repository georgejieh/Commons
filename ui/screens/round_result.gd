class_name RoundResult
extends RefCounted
## The player's result in one finished round, as its summary reads it from the events.

## Whether the player's side won.
var won: bool = false
## What the player scored, in Grain.
var score: float = 0.0
## What the Commons paid the player.
var share: int = 0
## Whether Overfulfillment's stake was settled in the round.
var staked: bool = false
## Whether the stake settled was won.
var stake_won: bool = false
## What the bank held once the stake was settled.
var banked: float = 0.0
## Whether Grain Tax took from the bank.
var taxed: bool = false
## What Grain Tax took.
var tax: float = 0.0
## Whether Overtime voided the bank.
var voided: bool = false


## The player's result in the last finished round of events, or null when none has.
static func last(events: Array[RunEvent]) -> RoundResult:
	var result: RoundResult = RoundResult.new()
	var finished: RoundResult = null
	var landlord: int = Seats.NONE
	for event: RunEvent in events:
		if event.round_event != null:
			var played: RoundEvent = event.round_event
			if played.type == RoundEvent.Type.ROUND_STARTED:
				landlord = played.seat
				result = RoundResult.new()
			elif played.type == RoundEvent.Type.ROUND_ENDED:
				result.won = (played.seat == landlord) == (landlord == Seats.PLAYER)
				finished = result
		elif event.seat == Seats.PLAYER:
			result.read(event)
	return finished


## Takes in one of the player's own events.
func read(event: RunEvent) -> void:
	match event.type:
		RunEvent.Type.ROUND_SCORED:
			score = event.amount
		RunEvent.Type.SHARE_PAID:
			share = event.value
		RunEvent.Type.STAKE_SETTLED:
			staked = true
			stake_won = event.value == 1
			banked = event.amount
		RunEvent.Type.GRAIN_TAXED:
			taxed = true
			tax = event.amount
		RunEvent.Type.BANK_VOIDED:
			voided = true
