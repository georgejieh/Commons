class_name CampaignRound
extends RefCounted
## What Campaigns hold in force for one round: a Letter waiting on the player's play, the
## seat it makes pass, Overfulfillment's stake and the round's debuff for Appeal. A new
## one starts with every round, so nothing outlasts it, and a replay of the Set's
## commands builds it again.

## An Anonymous Letter used this turn, waiting for the player's play.
var letter_armed: bool = false
## The seat that must pass the play it answers, or Seats.NONE.
var forced_seat: int = Seats.NONE
## Overfulfillment: the bank is multiplied by win_times on a win and voided on a loss.
var staked: bool = false
var win_times: int = 1
## This round's debuff from the ladder, as the stack holds it, or null on a clean round.
var round_debuff: ActiveModifier = null
## The debuff Appeal lifted, or an empty ID.
var lifted: String = RunState.NO_DEBUFF
