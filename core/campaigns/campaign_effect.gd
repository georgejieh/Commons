class_name CampaignEffect
extends RefCounted
## Base for a Campaign's behaviour (ADR 0021). RunCampaigns checks the moment and the
## chosen cards; an effect checks what is its own, such as the player's side, and then
## applies itself. A check changes nothing.

## Why a Campaign cannot be used now. Each has its own reason string for the tray.
enum Reason {
	OK,
	NO_SUCH_SLOT,
	## Not the moment its rule names.
	NOT_NOW,
	NOT_PEASANT,
	NOT_LANDLORD,
	## The round's first play has been made.
	PLAY_STARTED,
	NO_DEBUFF,
	## Already in force this round or this turn.
	ALREADY_USED,
	CARD_COUNT,
	NOT_IN_HAND,
	ALREADY_MARKED,
	## A hand in the trade holds a single card.
	HAND_TOO_SMALL,
	## Two ranks are wild already, the most there can be (ADR 0029).
	WILD_FULL,
}

var parameters: Dictionary[String, int] = {}


## Names every parameter the definition must supply.
func required_parameters() -> PackedStringArray:
	return PackedStringArray()


func check(_context: CampaignContext) -> Reason:
	return Reason.OK


func apply(_context: CampaignContext) -> void:
	pass
