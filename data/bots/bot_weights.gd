class_name BotWeights
extends Resource
## The numbers behind bot play.

## Most positions the minimum-hands search remembers in one decision.
@export var memo_cap: int
## What each round still needed costs a hand (sm9sun's baseline is 7).
@export var round_penalty: float
## Subtracted from a group's top rank, so low cards are worth less than nothing.
@export var rank_offset: float
## Added to a group's value, by Pattern.Type.
@export var type_bonus: PackedFloat32Array
## What emptying the hand is worth. Larger than any hand's value.
@export var win_value: float
## An opponent on this many cards or fewer must be stopped.
@export var block_cards: int
## A landlord on this many cards or fewer opens the peasants' bomb gate.
@export var runaway_cards: int
## The upstream seat tops a teammate's card below this rank.
@export var weak_teammate_rank: int
## The lowest rank the upstream seat blocks with.
@export var block_low_rank: int
## Bid points, from the Plan.
@export var big_joker_points: float
@export var small_joker_points: float
@export var two_points: float
@export var ace_points: float
@export var bomb_points: float
@export var rocket_points: float
## Each hand under par adds shape_points.
@export var shape_par_hands: float
@export var shape_points: float
@export var call_threshold: float
@export var grab_threshold: float
## Scales the bar for the last seat to decide.
@export var last_bidder_factor: float
## The share of deals that should find a landlord.
@export var bid_rate_low: float
@export var bid_rate_high: float
## How many top candidates a search rolls out, and how many deals of the unseen cards.
@export var hard_candidates: int
@export var hard_samples: int
@export var expert_candidates: int
@export var expert_samples: int
## Hard searches once this few cards are left around the table, itself included.
@export var endgame_cards: int
## Actions after which a rollout counts as a loss.
@export var search_step_limit: int
