class_name TutorialScript
extends Resource
## The arrival, authored whole (ADR 0026): its seed, its one Quota, both deals and what
## the villagers do in them, what the two counters hold, the scripted Denunciation and
## the ordered steps.

## The seed of the run's streams.
@export var seed_value: int = 0
## The Quota: two rounds, and a target the authored plays fall short of. It is a figure a
## player can read (the plays score under half of it), never a stand-in.
@export var sets: SetParams
## The coupons the player starts with.
@export var starting_coupons: int = 10
## A ladder with no budget, so no round draws a debuff.
@export var ladder: LadderParams
## The state store's numbers.
@export var store: ShopParams
## The ID of the one Cadre the state store holds.
@export var store_cadre: String = ""
## The black market's numbers: no Cadres, nothing drawn.
@export var market: ShopParams
## The one plot card on the black market's stall.
@export var plot_cards: CardStallParams
## Each round's authored deal and what the villagers do in it.
@export var rounds: Array[TutorialRound] = []
## What the plot card's purchase adds to Denunciation, through its own meter table row.
@export var denunciation: int = 10
## Seconds a follow-up line holds before the next prompt may replace it.
@export var follow_seconds: float = 1.6
## The ordered steps.
@export var steps: Array[TutorialStep] = []
