class_name PlayContext
extends RefCounted
## Passed to the play scored hook. It runs for previews too, so an effect only reads its
## CadreMemo here; counting belongs in the turn taken hook.

## The seat making the play.
var seat: int
## True when that seat is the round's landlord.
var is_landlord: bool
## The play being scored.
var pattern: Pattern
## Summed, then applied before add_zeal.
var add_grain: float
## Summed, then applied before mul_zeal.
var add_zeal: float
## Multiplied last.
var mul_zeal: float
## The seat's plays before this one in the round, so effects need no state of their own.
var plays_before: int = 0
## Grain before the hooks: the scored cards' values.
var grain: float = 0.0
## Grain per base rank, for effects that score cards the play doesn't.
var card_grain: Array[int] = []
## The printed ranks of the cards the reading puts in its kickers (ADR 0029), which are
## the kicker ranks unless a wild card stands in.
var kicker_cards: PackedByteArray = PackedByteArray()
## The printed ranks of the cards the play scores, in play order (ADR 0032).
var body_cards: PackedByteArray = PackedByteArray()
## The run's Year in play, from 1, or 0 when the scorer was not given the run.
var year: int = 0
## False when a hook waives the Resentment the seat's stamped cards add as they score
## (Forged Seal, ADR 0032). Read once the play is scored.
var stamps_resented: bool = true
## The share of its Rate the play keeps, in percent, rounded up (ADR 0023). Applied before
## the cap.
var rate_percent: int = 100
## The most Rate the play may score with, whatever its hand type and level.
var rate_cap: float = INF
## Multiplies the finished total, after every other step and the cap.
var total_scale: float = 1.0
## The round's landlord, or Seats.NONE outside a round.
var landlord: int = Seats.NONE
## Cards left in the seat's hand once this play is made, or -1 when unknown.
var cards_left: int = -1
## Each seat's plays so far this round. Empty when the scorer was not given the round.
var seat_plays: PackedInt32Array = PackedInt32Array()
## Each seat's Grain from its last play this round. Empty when the scorer was not given the round.
var seat_grain: PackedFloat64Array = PackedFloat64Array()


func _init(
	seat_value: int,
	is_landlord_value: bool,
	pattern_value: Pattern,
	add_grain_value: float,
	add_zeal_value: float,
	mul_zeal_value: float,
) -> void:
	seat = seat_value
	is_landlord = is_landlord_value
	pattern = pattern_value
	add_grain = add_grain_value
	add_zeal = add_zeal_value
	mul_zeal = mul_zeal_value


## The other peasant's seat when this seat is a peasant, else Seats.NONE.
func teammate() -> int:
	return Seats.teammate(seat, landlord)
