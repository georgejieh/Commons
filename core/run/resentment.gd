class_name Resentment
extends RefCounted
## The village's Resentment of the player's private gains (P4.2). It rises from private
## purchases, private Cadres, stamped cards scored and grabbing the landlord seat. It
## feeds Denunciation at each Set's end through one data curve, and sharpens every bot's
## grudge against the player.

const PRIVATE_PURCHASE: String = "private_purchase"
const PRIVATE_CADRE: String = "private_cadre"
const STAMPED_CARD: String = "stamped_card"
const GRAB: String = "grab"


static func add(
	state: RunState, amount: int, cause: String, params: ResentmentParams, events: Array[RunEvent]
) -> void:
	var before: int = state.resentment
	state.resentment = clampi(before + amount, 0, params.max)
	if state.resentment != before:
		events.append(
			RunEvent.new(
				RunEvent.Type.RESENTMENT, Seats.NONE, state.resentment - before, 0.0, cause
			)
		)


## Private Cadres held at a Set's end.
static func private_cadres(cadres: Array[String], pool: Array[ModifierDef]) -> int:
	var count: int = 0
	for definition: ModifierDef in pool:
		if definition.tag == ModifierDef.Tag.PRIVATE and cadres.has(definition.id):
			count += 1
	return count


## Cards in a play that carry the seat's own stamp.
static func stamped(cards: Array[CardInstance], seat: int) -> int:
	return cards.filter(func(card: CardInstance) -> bool: return card.owner_stamp() == seat).size()


## The Denunciation a Set's end adds at this Resentment.
static func denunciation(resentment: int, params: ResentmentParams) -> int:
	return roundi(params.denunciation.sample(float(resentment) / params.max))


## What every bot holds against the player at this Resentment.
static func grudge(resentment: int, params: ResentmentParams) -> float:
	return params.grudge_at_max * resentment / params.max
