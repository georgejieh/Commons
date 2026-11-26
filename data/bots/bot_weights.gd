class_name BotWeights
extends Resource
## The numbers behind bot play.

## Most positions, in positions, the minimum-hands search remembers in one decision.
@export var memo_cap: int
## What each round still needed costs a hand, in hands.
@export var round_penalty: float
## Subtracted from a group's top rank, in ranks, so low cards are worth less than nothing.
@export var rank_offset: float
## Added to a group's value, by Pattern.Type.
@export var type_bonus: PackedFloat32Array
## What emptying the hand is worth. Larger than any hand's value.
@export var win_value: float
## An opponent on this many cards or fewer, in cards, must be stopped.
@export var block_cards: int
## A landlord on this many cards or fewer, in cards, opens the peasants' bomb gate.
@export var runaway_cards: int
## The upstream seat tops a teammate's card below this rank.
@export var weak_teammate_rank: int
## The lowest rank the upstream seat blocks with.
@export var block_low_rank: int
## Bid points each big joker held adds to a hand's worth.
@export var big_joker_points: float
## Bid points each small joker held adds.
@export var small_joker_points: float
## Bid points each 2 held adds.
@export var two_points: float
## Bid points each ace held adds.
@export var ace_points: float
## Bid points each bomb held adds.
@export var bomb_points: float
## Bid points holding both jokers adds.
@export var rocket_points: float
## Each wild card held while a rank is wild (ADR 0029), from the value of a 2. Nothing
## reads it while no rank is wild.
@export var wild_card_points: float
## A hand that splits into fewer plays than this, in hands, is well shaped, and each play
## under it adds shape_points.
@export var shape_par_hands: float
## Bid points each play under shape_par_hands adds.
@export var shape_points: float
## The bid points a hand needs for a bot to call for the landlord seat.
@export var call_threshold: float
## The bid points a hand needs for a bot to grab the seat from a caller.
@export var grab_threshold: float
## Scales the bar for the last seat to decide.
@export var last_bidder_factor: float
## The least share of deals, from 0 to 1, that should find a landlord; the bidding test
## holds the bots to it.
@export var bid_rate_low: float
## The most share of deals, from 0 to 1, that should find a landlord.
@export var bid_rate_high: float
## How many top candidate plays an Expert search rolls out.
@export var expert_candidates: int
## How many deals of the unseen cards an Expert search rolls out each candidate over.
@export var expert_samples: int
## A rival beats the policy's play only by this share of the samples run, so noise can't
## overturn it (ADR 0011).
@export var expert_margin: float
## Fewer finished samples than this, in samples, leave the policy's play standing.
@export var expert_min_samples: int
## How long the live game gives one Expert decision, in microseconds: at the deadline the
## search starts no more samples (ADR 0030, measured at ADR 0011's 300 ms).
@export var expert_deadline_usec: int
## How long past the deadline a sample already running may go on. After it the
## sample is abandoned, which holds a decision under 400 ms on any machine.
@export var expert_grace_usec: int
## Actions after which a rollout counts as a loss, in plays and passes.
@export var search_step_limit: int
