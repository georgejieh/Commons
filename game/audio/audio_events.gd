class_name AudioEvents
extends RefCounted
## Names the sound for every domain event (P3B.10). Views pass the event here and play
## the name on the Audio autoload; sounds themselves arrive with P3C.8.

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


## The sound for an event. ROUND events take their round event's name.
static func name_for(event: RunEvent) -> String:
	if event.type != RunEvent.Type.ROUND:
		return RUN_NAMES[event.type]
	var round_event: RoundEvent = event.round_event
	if round_event.type == RoundEvent.Type.PLAYED and round_event.pattern != null:
		var type: Pattern.Type = round_event.pattern.type
		if type == Pattern.Type.BOMB or type == Pattern.Type.ROCKET:
			return BOMB_NAME
	return ROUND_NAMES[round_event.type]
