class_name SeatScope
extends RefCounted
## Whose seat a modifier acts for (ADR 0039). Whatever the player buys works for the
## household that holds it: the rule and rank hooks of a Cadre or a Reform build the
## holder's seat alone, so no villager gains a rule the player paid for. A Cadre's scoring
## hooks pay on the holder's plays, and on the teammate's while the holder is a peasant
## when its definition says it counts for them; a Reform's score whatever play its rule
## allows, which only the holder can make. Debuffs and boss twists keep the reach their
## own effects give them. The stack asks this before it runs a seat hook, so no
## effect needs a guard of its own, and a helper an effect shares with a debuff keeps its
## meaning.

enum Reach { TABLE, HOLDER, SIDE }


## Whose seats a definition's build_ruleset and build_rank_map hooks build: the holder's
## alone for anything the player buys, every seat for a debuff or a boss twist.
static func rules_reach(definition: ModifierDef) -> Reach:
	match definition.kind:
		ModifierDef.Kind.DEBUFF, ModifierDef.Kind.BOSS_TWIST:
			return Reach.TABLE
	return Reach.HOLDER


## Whose plays a definition's play_scored and card_scored hooks score.
static func score_reach(definition: ModifierDef) -> Reach:
	if definition.kind != ModifierDef.Kind.CADRE:
		return Reach.TABLE
	return Reach.SIDE if definition.counts_for_teammate else Reach.HOLDER


## True when an effect of this reach, held by holder, acts for seat in a round whose
## landlord is landlord. Seats.NONE for the landlord means outside a round, where nobody
## has a teammate.
static func reaches(reach: Reach, holder: int, seat: int, landlord: int) -> bool:
	match reach:
		Reach.TABLE:
			return true
		Reach.HOLDER:
			return seat == holder
	return seat == holder or are_teammates(holder, seat, landlord)


## True when both seats are this round's peasants and not the same seat.
static func are_teammates(holder: int, seat: int, landlord: int) -> bool:
	return seat != Seats.NONE and seat == Seats.teammate(holder, landlord)


## True when the seat is a peasant in a round whose landlord is known.
static func is_peasant(seat: int, landlord: int) -> bool:
	return landlord != Seats.NONE and seat != Seats.NONE and seat != landlord
