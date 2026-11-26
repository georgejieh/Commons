class_name BidParams
extends Resource
## The numbers behind call-and-grab bidding.

## The round's stake before any grab, as a multiplier of its score.
@export var base_stake: int
## What the stake is multiplied by each time the landlord seat is grabbed.
@export var grab_multiplier: int
