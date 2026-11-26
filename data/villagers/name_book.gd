class_name NameBook
extends Resource
## Every name the game draws or refuses (ADR 0028), made from the ADR's lists: the era
## pools by generation, the given names blocked with every surname, the full names blocked
## as a pair ("Surname Given", as the ADR writes them), the surnames the first launch
## offers, and the surname a run uses when the profile holds none.

## The era pools of given names, in generation order.
@export var pools: Array[NamePool] = []
## Given names that are never drawn, with any surname.
@export var blocked_given: Array[String] = []
## Full names, written "Surname Given", that are never drawn.
@export var blocked_pairs: Array[String] = []
## The surnames the first launch offers.
@export var offered_surnames: Array[String] = []
## For a profile with no surname, which only tests and the demo can have.
@export var fallback_surname: String = "Zhang"


## The pool a generation draws from: the last one whose first generation it has reached,
## and the first pool for generation 0, a run outside the profile.
func pool_index(generation: int) -> int:
	var found: int = 0
	for index: int in pools.size():
		if pools[index].first_generation <= maxi(generation, 1):
			found = index
	return found


## True when the given name may never be drawn with this surname.
func blocked(surname: String, given: String) -> bool:
	if blocked_given.has(given):
		return true
	return blocked_pairs.has("%s %s" % [surname, given])
