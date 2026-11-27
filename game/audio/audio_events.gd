class_name AudioEvents
extends RefCounted
## Names the sound for every domain event. Views pass the event here and play the name on
## the Audio autoload, which plays its sound effect.

## The sound name for each RunEvent type; "" for one that brings no sound of its own.
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
## The sound name for each RoundEvent type, used when a ROUND event wraps one.
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
## The sound a played Rocket makes, over the plain play's.
const ROCKET_NAME: String = "rocket_played"
## A finished round sounds won or lost from the player's side once the landlord is known.
const ROUND_WON: String = "round_won"
## The sound of a round the player's side lost.
const ROUND_LOST: String = "round_lost"
## A meter rising past one of its marks.
const METER_ROSE: String = "meter_rose"
## A Cadre bought in the state store.
const STORE_BUY: String = "store_buy"
## One card counted in a scored play acted out.
const SCORE_TICK: String = "score_tick"
## The Rate landing in a scored play.
const SCORE_RATE: String = "score_rate"
## The Zeal landing in a scored play.
const SCORE_ZEAL: String = "score_zeal"
## A change that raised the score.
const SCORE_CHIME: String = "score_chime"
## A change that cut the score.
const SCORE_CUT: String = "score_cut"
## The total rolling up before it lands.
const SCORE_ROLL: String = "score_roll"
## The total landing.
const SCORE_LAND: String = "score_land"
## The total landing when it is a big one.
const SCORE_LAND_HEAVY: String = "score_land_heavy"
## A stamp landing. The MOTION_ and later sounds below are a motion's own, filled in by
## Audio.fill only where its event has none.
const MOTION_STAMP: String = "motion_stamp"
## A swell, as a figure pulses.
const MOTION_PULSE: String = "motion_pulse"
## A number rolling.
const MOTION_COUNT: String = "motion_count"
## A page's pieces arriving.
const MOTION_ENTER: String = "motion_enter"
## A picture laid down.
const MOTION_SETTLE: String = "motion_settle"
## A hover over something that can be pressed.
const MOTION_HOVER: String = "motion_hover"
## A figure in flight.
const MOTION_FLY: String = "motion_fly"
## A villager taking up their cards.
const MOTION_WIND: String = "motion_wind"
## The ink wipe between screens.
const MOTION_WIPE: String = "motion_wipe"
## A banner across the table.
const CALLOUT_CUT: String = "callout_cut"
## The audit's dice.
const DICE_ROLL: String = "dice_roll"
## The Quota met.
const QUOTA_MET: String = "quota_met"
## The Quota missed.
const QUOTA_MISSED: String = "quota_missed"


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
		var won: bool = (round_event.seat == landlord) == (RunLoop.PLAYER == landlord)
		return ROUND_WON if won else ROUND_LOST
	return ROUND_NAMES[round_event.type]


## True when the event is the player laying cards on the table.
static func played_by_player(event: RunEvent) -> bool:
	return (
		event.type == RunEvent.Type.ROUND
		and event.round_event.type == RoundEvent.Type.PLAYED
		and event.round_event.seat == RunLoop.PLAYER
	)


## True when a meter moving from before to after rises past any of the marks.
static func meter_rose(before: int, after: int, marks: Array[int]) -> bool:
	for mark: int in marks:
		if before < mark and after >= mark:
			return true
	return false
