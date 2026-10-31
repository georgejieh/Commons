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
