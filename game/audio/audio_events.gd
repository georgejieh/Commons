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
	RunEvent.Type.AUDIT_ROLLED: "audit_rolled",
	RunEvent.Type.OVERFULFILLED: "overfulfilled",
	RunEvent.Type.CAMPAIGN_USED: "campaign_used",
	RunEvent.Type.CARDS_MARKED: "cards_marked",
	RunEvent.Type.CARDS_MOVED: "cards_moved",
	RunEvent.Type.PASS_FORCED: "pass_forced",
	RunEvent.Type.LETTER_LAPSED: "letter_lapsed",
	RunEvent.Type.STAKE_SETTLED: "stake_settled",
	RunEvent.Type.DEBUFF_LIFTED: "debuff_lifted",
	RunEvent.Type.COUPONS_GAINED: "coupons_gained",
	RunEvent.Type.CADRE_FIRED: "cadre_fired",
	RunEvent.Type.CARDS_PASSED: "cards_passed",
	RunEvent.Type.CADRE_CONFISCATED: "cadre_confiscated",
	RunEvent.Type.PLOT_SEIZED: "plot_seized",
	RunEvent.Type.GRAIN_TAXED: "grain_taxed",
	RunEvent.Type.BANK_VOIDED: "bank_voided",
	RunEvent.Type.STARVED: "family_starved",
	RunEvent.Type.DEPOSED: "family_deposed",
	# The Famine it adds sounds as a meter change.
	RunEvent.Type.STOOD_BY: "",
	# The call-out that names a wild rank lands with the store's stamp (ADR 0029).
	RunEvent.Type.WILD_RANKS: "store_buy",
	# The notice that the books were corrected brings its own sound (ADR 0022).
	RunEvent.Type.BOOKS_CORRECTED: "",
	# A sale back to a shop sounds as the shop's own stamp, which the screen plays.
	RunEvent.Type.CADRE_SOLD: "",
	RunEvent.Type.CAMPAIGN_SOLD: "",
	# The desk's mark is pressed with the shop's own stamp, which the screen plays.
	RunEvent.Type.DECK_CARD_MARKED: "",
	# What the deal shows before the bid comes with the deal's own sound (ADR 0043).
	RunEvent.Type.CARDS_SET_ASIDE: "",
	RunEvent.Type.KITTY_SEEN: "",
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
## A scored play acted out (P5.2a): each card counted, the Rate and Zeal landing, a
## change that raised the score and one that cut it, the total rolling up and landing,
## harder for a big one.
const SCORE_TICK: String = "score_tick"
const SCORE_RATE: String = "score_rate"
const SCORE_ZEAL: String = "score_zeal"
const SCORE_CHIME: String = "score_chime"
const SCORE_CUT: String = "score_cut"
const SCORE_ROLL: String = "score_roll"
const SCORE_LAND: String = "score_land"
const SCORE_LAND_HEAVY: String = "score_land_heavy"
## A motion's own sound, filled in by Audio.fill only where its event has none (P5.2a):
## a stamp landing, a swell, a number rolling, a page's pieces arriving, a picture laid
## down, a hover, a figure in flight, a villager taking up their cards, the ink wipe
## between screens, a banner across the table, the audit's dice, and the Quota met or
## missed.
const MOTION_STAMP: String = "motion_stamp"
const MOTION_PULSE: String = "motion_pulse"
const MOTION_COUNT: String = "motion_count"
const MOTION_ENTER: String = "motion_enter"
const MOTION_SETTLE: String = "motion_settle"
const MOTION_HOVER: String = "motion_hover"
const MOTION_FLY: String = "motion_fly"
const MOTION_WIND: String = "motion_wind"
const MOTION_WIPE: String = "motion_wipe"
const CALLOUT_CUT: String = "callout_cut"
const DICE_ROLL: String = "dice_roll"
const QUOTA_MET: String = "quota_met"
const QUOTA_MISSED: String = "quota_missed"
## Every name above, for the bank's test.
const MOTION_NAMES: Array[String] = [
	SCORE_TICK,
	SCORE_RATE,
	SCORE_ZEAL,
	SCORE_CHIME,
	SCORE_CUT,
	SCORE_ROLL,
	SCORE_LAND,
	SCORE_LAND_HEAVY,
	MOTION_STAMP,
	MOTION_PULSE,
	MOTION_COUNT,
	MOTION_ENTER,
	MOTION_SETTLE,
	MOTION_HOVER,
	MOTION_FLY,
	MOTION_WIND,
	MOTION_WIPE,
	CALLOUT_CUT,
	DICE_ROLL,
	QUOTA_MET,
	QUOTA_MISSED,
]


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


## True when the event is the player laying cards on the table.
static func played_by_player(event: RunEvent) -> bool:
	return (
		event.type == RunEvent.Type.ROUND
		and event.round_event.type == RoundEvent.Type.PLAYED
		and event.round_event.seat == PLAYER
	)


## True when a meter moving from before to after rises past any of the marks.
static func meter_rose(before: int, after: int, marks: Array[int]) -> bool:
	for mark: int in marks:
		if before < mark and after >= mark:
			return true
	return false
