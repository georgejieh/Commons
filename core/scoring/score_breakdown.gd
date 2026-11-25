class_name ScoreBreakdown
extends RefCounted
## One play's score, and for a real play the trail of every change to it.

var grain: float = 0.0
var rate: float = 0.0
var zeal: float = 0.0
var total: float = 0.0
## False when a hook waived the Resentment the play's stamped cards add (ADR 0032).
var stamps_resented: bool = true
## The scored Surplus cards' IDs, in play order, which pay the player coupons (ADR 0041).
var surplus_cards: Array[int] = []
## Every change to the score, one at a time, for the table to act out. Kept only
## when the scorer was asked to record, as for a real play; empty for a preview.
var trail: Array[ScoreStep] = []
