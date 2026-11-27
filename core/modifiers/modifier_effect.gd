class_name ModifierEffect
extends RefCounted
## Base for effect scripts. A subclass overrides the hooks its definition lists.

## The definition's parameters, copied in by the registry. Read only keys that required_parameters()
## names.
var parameters: Dictionary[String, int] = {}
## The seat that holds this modifier, for effects that say "your".
var holder_seat: int = Seats.NONE
## This Cadre's own run state (ADR 0021). The run loop binds a held Cadre's saved entry;
## anything else keeps a fresh one the run never saves.
var memo: CadreMemo = CadreMemo.new()


## A number given in hundredths as a fraction, as every parameter named in percent or in
## hundredths is read: 150 is 1.5.
static func fraction(hundredths: float) -> float:
	return hundredths / Scorer.PERCENT


## Names every parameter the definition must supply.
func required_parameters() -> PackedStringArray:
	return PackedStringArray()


## Names the parameters that must be valid ranks.
func rank_parameters() -> PackedStringArray:
	return PackedStringArray()


## Where the Cadre stands, from its memo, for its state line: numbers by placeholder
## name, ranks under names that start with "rank", and "count" for its badge. Empty
## for a Cadre that keeps no state.
func state_values() -> Dictionary[String, Variant]:
	return {}


## Hook: edits the RuleSet of the seat being built, on a private copy of its params.
func build_ruleset(_context: RulesetContext) -> void:
	pass


## Hook: edits the effective-rank map of the seat being built.
func build_rank_map(_context: RankMapContext) -> void:
	pass


## Hook: runs once the round is dealt, with the deal, which it may change.
func on_deal(_context: DealContext) -> void:
	pass


## Not a hook: called when a Cadre left out of the round at its start is handed back in
## it (ADR 0023), with the round's deal, which its deal hook never saw.
func handed_back(_deal: DealResult) -> void:
	pass


## Hook: runs as the round starts, after the kitty and before the first play.
func round_start(_context: RoundContext) -> void:
	pass


## Hook: runs for every play scored, a preview too, to change its Grain and Zeal. Only read the memo
## here; count in turn_taken.
func play_scored(_context: PlayContext) -> void:
	pass


## Hook: runs for each card of a play as it scores, to change that card's Grain.
func card_scored(_context: CardContext) -> void:
	pass


## Hook: runs when the round has ended, before its totals fill the Commons.
func round_end(_context: RoundContext) -> void:
	pass


## Hook: runs when the Set has ended, to add coupons or Resentment by whether the Quota was met.
func set_end(_context: SetContext) -> void:
	pass


## Hook: runs as a shop opens, to change what this visit offers.
func shop_open(_context: ShopContext) -> void:
	pass


## Hook: runs when a meter is about to change, to edit the change.
func meter_change(_context: MeterContext) -> void:
	pass


## Hook: runs before declared needs are checked, to change how many faces of the audit die mean a
## check.
func audit(_context: AuditContext) -> void:
	pass


## Hook: runs after each real play or pass, never a preview, so it may count what it sees in its
## memo.
func turn_taken(_context: TurnContext) -> void:
	pass


## Hook: runs once the round's Commons is split and its audit done, to change what the declaration
## earns or costs.
func need_settled(_context: NeedContext) -> void:
	pass
