class_name ModifierEffect
extends RefCounted
## Base for effect scripts. A subclass overrides the hooks its definition lists.

var parameters: Dictionary[String, int] = {}
## The seat that holds this modifier, for effects that say "your".
var holder_seat: int = Seats.NONE
## This Cadre's own run state (ADR 0021). The run loop binds a held Cadre's saved entry;
## anything else keeps a fresh one the run never saves.
var memo: CadreMemo = CadreMemo.new()


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


func build_ruleset(_context: RulesetContext) -> void:
	pass


func build_rank_map(_context: RankMapContext) -> void:
	pass


func on_deal(_context: DealContext) -> void:
	pass


func round_start(_context: RoundContext) -> void:
	pass


func play_scored(_context: PlayContext) -> void:
	pass


func card_scored(_context: CardContext) -> void:
	pass


func trick_won(_context: TrickContext) -> void:
	pass


func round_end(_context: RoundContext) -> void:
	pass


func set_end(_context: SetContext) -> void:
	pass


func shop_open(_context: ShopContext) -> void:
	pass


func meter_change(_context: MeterContext) -> void:
	pass


func audit(_context: AuditContext) -> void:
	pass


func turn_taken(_context: TurnContext) -> void:
	pass


func need_settled(_context: NeedContext) -> void:
	pass
