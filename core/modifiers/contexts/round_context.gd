class_name RoundContext
extends RefCounted
## Passed to the round start and round end hook.

## swap_cap while no hook caps the round's plot swaps.
const NO_CAP: int = -1

var landlord: int
## Seats.NONE at round start.
var winner: int
var finish: RoundEvent.Finish
## At round end: multiplies the peasants' totals before they fill the Commons, to edit.
var commons_scale: float = 1.0

## At round start, after the kitty and before the plot swap: the round, its rules and
## the deal stream, so a debuff can move cards between hands (ADR 0023). Null when the
## hook runs outside a round.
var round_state: RoundState = null
var table: SeatRules = null
var stream: RandomStream = null
## The debuff that came into force this round, or null, so an effect that acts once when
## it arrives can tell.
var arrived: ModifierEffect = null
## At round start, to edit: the most private-plot swaps this round, or NO_CAP, and how
## many plot cards are destroyed now.
var swap_cap: int = NO_CAP
var seize_plot: int = 0
## Every move trade() made, in order, for the run to log.
var moves: Array[CardPass] = []

## At round end, to edit: the holder banks nothing this round, a share of what it banks
## is taken in percent, and the meter table rows to raise.
var bank_voided: bool = false
var tax_percent: int = 0
var meter_sources: Array[String] = []
## At round end: the cards the landlord still holds (ADR 0032), and the Famine the round
## takes off the player's meter, to edit.
var landlord_cards: int = 0
var famine_fall: int = 0


func _init(
	landlord_value: int,
	winner_value: int,
	finish_value: RoundEvent.Finish,
) -> void:
	landlord = landlord_value
	winner = winner_value
	finish = finish_value


## Caps the round's plot swaps at most at limit.
func cap_swaps(limit: int) -> void:
	swap_cap = limit if swap_cap == NO_CAP else mini(swap_cap, limit)


## Moves cards one for one between two seats through the round, keeping the public kitty
## honest, and records both moves.
func trade(seat_a: int, ids_a: Array[int], seat_b: int, ids_b: Array[int]) -> void:
	var done: RoundState.Reason = round_state.trade(seat_a, ids_a, seat_b, ids_b)
	assert(done == RoundState.Reason.OK, "A debuff's trade was refused")
	moves.append(CardPass.new(seat_a, seat_b, ids_a))
	moves.append(CardPass.new(seat_b, seat_a, ids_b))


## True when the seat's side lost the finished round.
func side_lost(seat: int) -> bool:
	if winner == Seats.NONE:
		return false
	return (seat == landlord) != (winner == landlord)
