class_name UiBoundaryCheck
extends RefCounted
## Scans UI scripts for anything that could change run state without a command:
## the core loop and round types, and the mutators on them, and the controller's way in
## for tests and tools. The UI reaches a run only through RunController's commands and
## the views it builds, which hand out copies. A script's comments are not read; its
## strings are, a hash in one included.

const FORBIDDEN_WORDS: PackedStringArray = [
	"RunLoop",
	"RunRecord",
	"RunRecordMigrations",
	"RunShopVisit",
	"RoundSettlement",
	"QuotaClose",
	"RunSeating",
	"RoundState",
	"RoundAction",
	"ModifierStack",
	"CardModifiers",
	"PlotSwap",
	"RoundBanking",
	"RunMeters",
	"player_bid",
	"player_swap",
	"player_play",
	"player_need",
	"next_set",
	"start_set",
	"resume_at_checkpoint",
	"open_shop",
	"player_buy",
	"player_reroll",
	"player_market_buy",
	"player_market_reroll",
	"player_upgrade",
	"player_plot_card",
	"player_directive",
	"player_campaign",
	"player_begin",
	"player_market_campaign",
	"player_sell_cadre",
	"player_sell_campaign",
	"player_mark_card",
	"MarkDesk",
	"player_reform",
	"player_envelope_buy",
	"player_market_envelope",
	"player_envelope_pick",
	"open_envelope",
	"RunCampaigns",
	"CampaignContext",
	"CampaignCounter",
	"ReformCounter",
	"EnvelopeCounter",
	"EnvelopeContents",
	"EnvelopeItem",
	"RunReforms",
	"RunDebuffs",
	"BankCut",
	"CardPass",
	"DeckOrder",
	"CardMarks",
	"RunShop",
	"Endings",
	"EpilogueLine",
	"YearClass",
	"PlotStall",
	"DeckStall",
	"DeckExchange",
	"CardOffers",
	"player_deck_card",
	"PlotUpgrades",
	"VillageFates",
	"RunIdentity",
	"SummaryFold",
	"ProfileCommits",
	"RunUnlocks",
	"RunStakes",
	"RunPools",
	"RunOpening",
	"RunLineage",
	"CorruptionEvents",
	"RunTutorial",
	"ScriptedVillager",
	"RunNames",
	"VillageDrift",
	"set_log",
	"set_enhancement",
	"set_seal",
	"set_owner_stamp",
	"run_loop",
	"state_copy",
	"stock_with",
	"rebuild_modifiers",
]
const EXTENSIONS: PackedStringArray = ["gd", "tscn"]


## Returns one "path:line: word" entry per violation. A missing root is a violation.
static func scan(root: String) -> PackedStringArray:
	if not DirAccess.dir_exists_absolute(root):
		return PackedStringArray(["%s: folder not found" % root])
	var pattern: RegEx = RegEx.create_from_string("\\b(%s)\\b" % "|".join(FORBIDDEN_WORDS))
	var found: PackedStringArray = []
	for path: String in ToolFiles.under(root, EXTENSIONS):
		var text: String = FileAccess.get_file_as_string(path)
		if path.get_extension() == "gd":
			text = ScriptText.code_of(text)
		var lines: PackedStringArray = text.split("\n")
		for index: int in lines.size():
			var hit: RegExMatch = pattern.search(lines[index])
			if hit != null:
				found.append("%s:%d: %s" % [path, index + 1, hit.get_string()])
	return found
