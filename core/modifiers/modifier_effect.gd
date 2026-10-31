class_name ModifierEffect
extends RefCounted
## Base for effect scripts. A subclass overrides the hooks its definition lists.

var parameters: Dictionary[String, int] = {}
## The seat that holds this modifier, for effects that say "your".
var holder_seat: int = Seats.NONE


## Names every parameter the definition must supply.
func required_parameters() -> PackedStringArray:
	return PackedStringArray()


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
