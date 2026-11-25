class_name RunPools
extends RefCounted
## What one run may be offered, and the numbers its stake changes (ADR 0025), made once
## when the loop is built, from the run's identity alone, so a loaded save rebuilds the
## same pools and numbers. Every way an item is offered or handed over draws from here:
## both counters' Cadres, Directives, Campaigns, Reforms and envelope kinds, what the
## envelopes hold, and the Cadre reeducation gives in exchange. Lookups by ID stay on the
## whole pools. The arrival's counters hold only what its script puts on them (ADR 0026).

const STORE_CADRES: CadrePool = preload("res://data/run/cadre_pool.tres")
const MARKET_CADRES: CadrePool = preload("res://data/run/market_pool.tres")
const DIRECTIVES: DirectivePool = preload("res://data/run/directive_pool.tres")
const STORE_CAMPAIGNS: CampaignPool = preload("res://data/run/campaign_pool.tres")
const MARKET_CAMPAIGNS: CampaignPool = preload("res://data/run/market_campaign_pool.tres")
const REFORMS: ReformPool = preload("res://data/run/reform_pool.tres")
const STORE: ShopParams = preload("res://data/run/default_shop.tres")
const MARKET: ShopParams = preload("res://data/run/black_market.tres")
const AUDIT: AuditParams = preload("res://data/run/audit.tres")
const LADDER: LadderParams = preload("res://data/run/default_ladder.tres")
const PLOT_CARDS: CardStallParams = preload("res://data/run/plot_stall.tres")
const DECK_CARDS: CardStallParams = preload("res://data/run/deck_stall.tres")

var store_cadres: Array[ModifierDef]
var market_cadres: Array[ModifierDef]
var directives: Array[DirectiveDef]
var store_campaigns: Array[CampaignDef]
var market_campaigns: Array[CampaignDef]
var reforms: Array[ReformDef]
## Each counter's numbers: the state store's slots under the stake, and only the open
## envelope kinds.
var store: ShopParams
var market: ShopParams
var audit: AuditParams
var ladder: LadderParams
## What the black market's plot stall and the state store's deck stall offer.
var plot_cards: CardStallParams = PLOT_CARDS
var deck_cards: CardStallParams = DECK_CARDS
## The stake's numbers, its own and every lower stake's.
var stake: StakeDef


func _init(identity: RunIdentity) -> void:
	var open: int = RunUnlocks.open_tier(identity)
	stake = RunStakes.total(identity.stake)
	store_cadres = RunUnlocks.cadres(STORE_CADRES.cadres, open)
	market_cadres = RunUnlocks.cadres(MARKET_CADRES.cadres, open)
	directives = RunUnlocks.directives(DIRECTIVES.directives, open)
	store_campaigns = RunUnlocks.campaigns(STORE_CAMPAIGNS.campaigns, open)
	market_campaigns = RunUnlocks.campaigns(MARKET_CAMPAIGNS.campaigns, open)
	reforms = RunUnlocks.reforms(REFORMS.reforms, open)
	store = RunStakes.shop(STORE, stake.store_slot_cut, RunUnlocks.envelopes(STORE.envelopes, open))
	market = RunStakes.shop(MARKET, 0, RunUnlocks.envelopes(MARKET.envelopes, open))
	audit = RunStakes.audit(AUDIT, stake)
	ladder = RunStakes.ladder(LADDER, stake)
	if identity.is_tutorial():
		_arrival(RunTutorial.SCRIPT)


## The arrival's counters: one Cadre in the state store, nothing drawn at the black
## market but its one plot card, and a ladder with no budget.
func _arrival(script: TutorialScript) -> void:
	# New arrays, never cleared: an open pool may be the shared one itself.
	var kept: Array[ModifierDef] = []
	for definition: ModifierDef in STORE_CADRES.cadres:
		if definition.id == script.store_cadre:
			kept.append(definition)
	store_cadres = kept
	market_cadres = []
	directives = []
	store_campaigns = []
	market_campaigns = []
	reforms = []
	store = script.store
	market = script.market
	ladder = script.ladder
	plot_cards = script.plot_cards


## The Cadres reeducation may give in exchange: every open one of either counter.
func exchange() -> Array[ModifierDef]:
	return store_cadres + market_cadres
