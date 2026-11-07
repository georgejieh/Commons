class_name AudioEvents
extends RefCounted
## Names the sound for every domain event (P3B.10). Views pass the event here and play
## the name on the Audio autoload, which plays its sound effect (P3C.8).

const RUN_NAMES: Dictionary[RunEvent.Type, String] = {
	RunEvent.Type.SET_STARTED: "set_started",
	RunEvent.Type.DEBUFF_ADDED: "debuff_added",
	RunEvent.Type.DEALT: "dealt",
	RunEvent.Type.REDEALT: "redealt",
	RunEvent.Type.BID: "bid",
	RunEvent.Type.LANDLORD_CHOSEN: "landlord_chosen",
	RunEvent.Type.SWAPPED: "swapped",
	RunEvent.Type.ROUND: "",
	RunEvent.Type.PLAY_SCORED: "play_scored",
	RunEvent.Type.ROUND_SCORED: "round_scored",
	RunEvent.Type.BANKED: "banked",
	RunEvent.Type.NEED_DECLARED: "need_declared",
	RunEvent.Type.SHARE_PAID: "share_paid",
	RunEvent.Type.SEAT_KEPT: "seat_kept",
	RunEvent.Type.SEAT_LOST: "seat_lost",
	RunEvent.Type.METER_CHANGED: "meter_changed",
	RunEvent.Type.SET_ENDED: "set_ended",
	RunEvent.Type.SETBACK: "setback",
	RunEvent.Type.RUN_DIED: "run_died",
	RunEvent.Type.REEDUCATED: "reeducated",
	RunEvent.Type.RESENTMENT: "resentment",
	RunEvent.Type.AUDITED: "audited",
	RunEvent.Type.VILLAGER_DENOUNCED: "villager_denounced",
	RunEvent.Type.ROSTER_CHANGED: "roster_changed",
	RunEvent.Type.BOSS_CHOSEN: "boss_chosen",
	RunEvent.Type.CADRE_PURGED: "cadre_purged",
}
const ROUND_NAMES: Dictionary[RoundEvent.Type, String] = {
	RoundEvent.Type.ROUND_STARTED: "round_started",
	RoundEvent.Type.KITTY_TAKEN: "kitty_taken",
	RoundEvent.Type.PLAYED: "card_played",
	RoundEvent.Type.PASSED: "passed",
	RoundEvent.Type.TRICK_WON: "trick_won",
	RoundEvent.Type.ANNOUNCED: "cards_announced",
	RoundEvent.Type.ROUND_ENDED: "round_ended",
}
## Bombs and rockets get their own sound over the plain play.
const BOMB_NAME: String = "bomb_played"
const ROCKET_NAME: String = "rocket_played"
## A finished round sounds won or lost from the player's side once the landlord is known.
const ROUND_WON: String = "round_won"
const ROUND_LOST: String = "round_lost"
## A meter rising past one of its marks.
const METER_ROSE: String = "meter_rose"
## A Cadre bought in the state store.
const STORE_BUY: String = "store_buy"
## The player's seat.
const PLAYER: int = 0


## The sound for an event. ROUND events take their round event's name. With the landlord
## seat known, a finished round is won or lost for the player.
static func name_for(event: RunEvent, landlord: int = Seats.NONE) -> String:
	if event.type != RunEvent.Type.ROUND:
		return RUN_NAMES[event.type]
	var round_event: RoundEvent = event.round_event
	if round_event.type == RoundEvent.Type.PLAYED and round_event.pattern != null:
		var type: Pattern.Type = round_event.pattern.type
		if type == Pattern.Type.ROCKET:
			return ROCKET_NAME
		if type == Pattern.Type.BOMB:
			return BOMB_NAME
	if round_event.type == RoundEvent.Type.ROUND_ENDED and landlord != Seats.NONE:
		var won: bool = (round_event.seat == landlord) == (PLAYER == landlord)
		return ROUND_WON if won else ROUND_LOST
	return ROUND_NAMES[round_event.type]


## True when a meter moving from before to after rises past any of the marks.
static func meter_rose(before: int, after: int, marks: Array[int]) -> bool:
	for mark: int in marks:
		if before < mark and after >= mark:
			return true
	return false
