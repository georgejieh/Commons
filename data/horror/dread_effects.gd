class_name DreadEffects
extends Resource
## The thresholds and sizes of the four slow effects: the eyes on the card
## backs, the hand's tremble, the names leaving the wall roster and speech turning to
## slogans. Each effect's weight comes from the HorrorLayers that name it, gated by the
## corruption stage so a clean profile shows none of them; these numbers say what a weight
## looks like on the table.

## The name of the effect of the eyes on the card backs, as a HorrorLayer names it.
const EYES: String = "back_eyes"
## The name of the effect of the hand's tremble.
const TREMBLE: String = "tremble"
## The name of the effect of names leaving the wall roster.
const ROSTER: String = "roster"
## The name of the effect of speech turning to slogans.
const SLOGANS: String = "slogans"
## Every effect's name, in the order of the effects above.
const NAMES: Array[String] = [EYES, TREMBLE, ROSTER, SLOGANS]

@export_group("Eyes on the card backs")
## The eye's ink at full weight; it is printed fainter below.
@export var eye_ink: float = 0.75
## The weight from which the eye turns toward the pointer; under it the eye looks ahead.
@export var eyes_follow_at: float = 0.45
## How much of the way to the pointer the eye's gaze closes each second.
@export var eyes_follow_rate: float = 2.5

@export_group("The hand's tremble")
## How far a trembling card's print shakes each way, across and up, at full weight, in
## pixels.
@export var tremble_px: float = 2.0
## How fast it shakes, in shakes a second.
@export var tremble_hz: float = 7.0

@export_group("The wall roster")
## The share of the roster's names gone at full weight.
@export var roster_vanish: float = 0.6

@export_group("Slogans")
## The weight from which villagers' lines start turning into slogans; all of them are
## slogans at full weight.
@export var slogan_at: float = 0.35
## The weight from which a slogan is said by two villagers at once.
@export var unison_at: float = 0.8


## The share of the eye's gaze that turns toward the pointer at weight.
func follow_share(weight: float) -> float:
	return clampf((weight - eyes_follow_at) / maxf(0.001, 1.0 - eyes_follow_at), 0.0, 1.0)


## The share of villagers' lines that are slogans at weight.
func slogan_share(weight: float) -> float:
	return clampf((weight - slogan_at) / maxf(0.001, 1.0 - slogan_at), 0.0, 1.0)


## How many of count names are fading or gone at weight; a fraction is a name half gone.
func names_gone(weight: float, count: int) -> float:
	return clampf(weight, 0.0, 1.0) * roster_vanish * count
