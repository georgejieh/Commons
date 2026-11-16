class_name RunTutorial
extends RefCounted
## The arrival's script in a run (ADR 0026), held by the loop, never global. It deals
## each round's authored deck, hands each villager seat its round of authored decisions
## through a ScriptedVillager on its bot config, puts the round's authored faces on the
## run's own audit copy, and names the Denunciation the plot card's purchase adds. A
## tutorial run is never saved, so nothing here is.

const SCRIPT: TutorialScript = preload("res://data/run/tutorial/arrival.tres")
## The meter table row the plot card's Denunciation goes through.
const DENUNCIATION_ROW: String = "tutorial_denunciation"

## Scripted villager faults: an illegal authored move or a script that ran out.
var faults: int = 0
## Called once per fault, as well as counting it; the loop counts it as a refused action.
var on_fault: Callable = Callable()

var _script: TutorialScript
var _villagers: Array[ScriptedVillager] = []


## Puts a scripted villager on each villager seat's config.
func _init(script: TutorialScript, configs: Array[BotConfig]) -> void:
	_script = script
	for seat: int in range(1, configs.size()):
		var villager: ScriptedVillager = ScriptedVillager.new(seat)
		villager.on_fault = _fault
		configs[seat].scripted = villager
		_villagers.append(villager)


## The round's authored deal, with each villager's decisions and the audit's faces set
## for it. A round past the script deals the last round's deck again, as a fault.
func deal(round_index: int, audit: AuditParams) -> DealResult:
	if round_index >= _script.rounds.size():
		push_error("The arrival has no round %d" % (round_index + 1))
		_fault()
		round_index = _script.rounds.size() - 1
	var authored: TutorialRound = _script.rounds[round_index]
	for index: int in _villagers.size():
		_villagers[index].start(authored.seats[index + 1])
	audit.shown_faces = authored.audit_faces.duplicate()
	var cards: Array[CardInstance] = []
	for deck_id: int in authored.deal:
		cards.append(CardInstance.from_deck_id(deck_id))
	return Dealer.deal_in_order(cards)


## What the plot card's purchase adds to Denunciation.
func denunciation() -> int:
	return _script.denunciation


func _fault() -> void:
	faults += 1
	if on_fault.is_valid():
		on_fault.call()
