class_name RunEvent
extends RefCounted
## One thing that happened in a run. Round play arrives wrapped as ROUND events.

enum Type {
	SET_STARTED,
	DEBUFF_ADDED,
	DEALT,
	REDEALT,
	BID,
	LANDLORD_CHOSEN,
	SWAPPED,
	ROUND,
	PLAY_SCORED,
	ROUND_SCORED,
	BANKED,
	NEED_DECLARED,
	SHARE_PAID,
	SEAT_KEPT,
	SEAT_LOST,
	METER_CHANGED,
	SET_ENDED,
	## value 1 when a setback starts, 0 when it lifts; text names it.
	SETBACK,
	## A meter reached its death threshold; text names the meter.
	RUN_DIED,
	REEDUCATED,
	## value is the change; text names the cause.
	RESENTMENT,
	## A declared need was checked: value 1 when it was a lie, 0 when honest.
	AUDITED,
	## A villager's own Denunciation changed; value is the change.
	VILLAGER_DENOUNCED,
	## A family's roster status changed: value is the status, text the family.
	ROSTER_CHANGED,
	## A boss Set began: text is the boss ID.
	BOSS_CHOSEN,
	## The Purge destroyed a Cadre: text is its ID.
	CADRE_PURGED,
	## A declaring seat rolled the audit die: value is the face shown, amount the number
	## of faces that mean an audit. Every roll comes before any AUDITED.
	AUDIT_ROLLED,
	## A met Quota beat its target by a step or more: value is the steps earned.
	OVERFULFILLED,
	## The player used a held Campaign (ADR 0021): value is its slot, text its ID.
	CAMPAIGN_USED,
	## Cards in the player's hand took a mark for the run: value is CardInstance.mark_value()
	## of the mark, 0 for the player's stamp; text is the card IDs, joined by commas.
	CARDS_MARKED,
	## Cards moved from seat to the seat in value mid-round; text is their IDs.
	CARDS_MOVED,
	## An Anonymous Letter makes seat pass the play it was answering.
	PASS_FORCED,
	## An Anonymous Letter was spent for nothing: seat is the seat it was sent to.
	LETTER_LAPSED,
	## Overfulfillment settled the landlord's bank: value 1 when it doubled, 0 when it was
	## voided; amount is what is banked.
	STAKE_SETTLED,
	## Appeal lifted this round's debuff: value is the round, text the debuff ID.
	DEBUFF_LIFTED,
	## The player gained coupons outside a Set's reward: value is how many.
	COUPONS_GAINED,
	## A held Cadre fired in a way the player should see (ADR 0021): value is what it
	## fired for, such as coupons paid or 1 for a count that grew; text is its ID.
	CADRE_FIRED,
	## A debuff moved cards before play (ADR 0023): from seat to the seat in value; text
	## is their IDs, joined by commas.
	CARDS_PASSED,
	## Confiscation left a held Cadre out of the round: value is its slot, text its ID.
	CADRE_CONFISCATED,
	## Plot Seized destroyed a plot card for the run: value is its ID, text its rank and
	## suit, joined by a comma.
	PLOT_SEIZED,
	## Grain Tax took from what the player banked: value is the percent, amount what was
	## taken.
	GRAIN_TAXED,
	## Overtime voided the player's bank for a lost round: amount is what was voided.
	BANK_VOIDED,
	## A seated family starved at a Quota's end (ADR 0025): seat is where it sat, value
	## its fed count that Quota, text its family ID. It is dead for the rest of the run.
	STARVED,
	## A risen villager whose boss Quota the player met was put out of the landlord's seat
	## (ADR 0025): seat is where it sat, text its family ID.
	DEPOSED,
	## A Quota ended without the player holding the landlord's seat, at or past the grace
	## (ADR 0031): value is the steps it cost, 0 on the last free Quota, and amount the
	## Famine it added.
	STOOD_BY,
	## A rank became wild for the player's seat this round (ADR 0029, ADR 0039), drawn by
	## Mass Line after the deal or by Model Worker: value is the rank, text every rank wild
	## now, joined by commas, in the order they were drawn.
	WILD_RANKS,
	## Figures reported from outside the game were taken as official (ADR 0022): value is
	## the run's count of corrections, text the figures that differed, joined by commas,
	## and correction says what each was and what followed. An offence with nothing to
	## correct, such as a failed seal, has an empty correction.
	BOOKS_CORRECTED,
	## The player sold a held Cadre back at a shop (ADR 0040): value is the coupons paid,
	## text its ID.
	CADRE_SOLD,
	## The player sold a held Campaign back at a shop (ADR 0040): value is the coupons
	## paid, text its ID.
	CAMPAIGN_SOLD,
}

var type: Type
var seat: int
var value: int
var amount: float
var text: String
## Set only for ROUND events.
var round_event: RoundEvent
## Set only for PLAY_SCORED: the play's Grain, Rate and Zeal. amount is their product,
## times any total scale a hook set.
var grain: float = 0.0
var rate: float = 0.0
var zeal: float = 0.0
## Set only for PLAY_SCORED: every change to the play's score in the order it was made
## (P5.2a), so the table can act each one out. Never saved.
var steps: Array[ScoreStep] = []
## Set only for BOOKS_CORRECTED.
var correction: BooksCorrection = null


func _init(
	event_type: Type,
	acting_seat: int = Seats.NONE,
	event_value: int = 0,
	event_amount: float = 0.0,
	event_text: String = ""
) -> void:
	type = event_type
	seat = acting_seat
	value = event_value
	amount = event_amount
	text = event_text


static func wrap(event: RoundEvent) -> RunEvent:
	var wrapped: RunEvent = RunEvent.new(Type.ROUND, event.seat)
	wrapped.round_event = event
	return wrapped


## One line for golden logs.
func describe() -> String:
	if round_event != null:
		return "  " + round_event.describe()
	var line: String = "%s seat=%d value=%d" % [Type.keys()[type], seat, value]
	if amount != 0.0:
		line += " amount=%.3f" % amount
	if not text.is_empty():
		line += " " + text
	if correction != null and not correction.is_empty():
		line += " [%s]" % correction.describe()
	return line
