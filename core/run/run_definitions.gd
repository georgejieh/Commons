class_name RunDefinitions
extends RefCounted
## Every definition a run names by ID, keyed by that ID, over RunPools' whole pools: the
## debuffs, both counters' Cadres, the bosses, the Directives, both counters' Campaigns
## and the Reforms. Each table is built once, when the class is first used. Read them
## only: index one for an ID that must exist, or get() one that may not. A shop counter
## looks up in the pool it was given instead, since the arrival and tests hand it others.

## Every debuff, Cadre and boss by ID.
static var modifiers: Dictionary[String, ModifierDef] = _modifiers()
## Every Directive by ID.
static var directives: Dictionary[String, DirectiveDef] = _directives()
## Every Campaign of both counters by ID.
static var campaigns: Dictionary[String, CampaignDef] = _campaigns()
## Every Reform by ID.
static var reforms: Dictionary[String, ReformDef] = _reforms()


static func _modifiers() -> Dictionary[String, ModifierDef]:
	var found: Dictionary[String, ModifierDef] = {}
	var every: Array[ModifierDef] = (
		RunPools.DEBUFFS.debuffs
		+ RunPools.STORE_CADRES.cadres
		+ RunPools.MARKET_CADRES.cadres
		+ RunPools.BOSSES.all()
	)
	for definition: ModifierDef in every:
		found[definition.id] = definition
	return found


static func _directives() -> Dictionary[String, DirectiveDef]:
	var found: Dictionary[String, DirectiveDef] = {}
	for definition: DirectiveDef in RunPools.DIRECTIVES.directives:
		found[definition.id] = definition
	return found


static func _campaigns() -> Dictionary[String, CampaignDef]:
	var found: Dictionary[String, CampaignDef] = {}
	for definition: CampaignDef in (
		RunPools.STORE_CAMPAIGNS.campaigns + RunPools.MARKET_CAMPAIGNS.campaigns
	):
		found[definition.id] = definition
	return found


static func _reforms() -> Dictionary[String, ReformDef]:
	var found: Dictionary[String, ReformDef] = {}
	for definition: ReformDef in RunPools.REFORMS.reforms:
		found[definition.id] = definition
	return found
