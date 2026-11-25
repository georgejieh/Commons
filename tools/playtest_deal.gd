extends WalkBase
## The playtest's frames of what a deal shows before the bid (ADR 0043), in a sandbox put
## back after, as the playtest's file and wild-rank frames are. Neither the Handicap nor
## the Tally Clerk need come up in the walk's own run, so both are staged on the table at
## the bid: the Handicap as the Set's boss with two of a villager's dealt cards set aside,
## its beat photographed as the cards lie on the pile and again once they have left, with
## the rules slip naming them; then the kitty the Tally Clerk shows, face up under its
## note. Development only; tools/ never ships.

## When the set-aside beat is photographed: as the cards land, and once they have left.
const BEAT_SECONDS: Array[float] = [0.5, 2.6]
const ASIDE: int = 2


## The table's frames, from the round under way, put back as they were after.
func table() -> void:
	var controller: Object = _controller()
	var loop: RunLoop = _loop()
	var deal: DealResult = member(loop, "_deal")
	if deal == null:
		_fail("NO DEAL FOR THE DEAL FRAMES")
		return
	var snapshot: Dictionary = loop.record.to_dict()
	var was_boss: String = loop.state.boss_id
	app.call("show_screen", "table", true)
	await _frames(20)
	await _until(_idle)
	loop.state.boss_id = "the_handicap"
	var ids: PackedStringArray = []
	for card: CardInstance in deal.hands[1].cards().slice(0, ASIDE):
		deal.set_aside.append(card)
		ids.append(str(card.id()))
	var beats: Object = _part("_deal_beats")
	var pile: Object = _part("_pile")
	pile.call("clear")
	var aside: RunEvent = RunEvent.new(RunEvent.Type.CARDS_SET_ASIDE, 0, 0, 0.0, ",".join(ids))
	beats.call("on_event", aside, false)
	var waited: float = 0.0
	for index: int in BEAT_SECONDS.size():
		await tree.create_timer(BEAT_SECONDS[index] - waited).timeout
		waited = BEAT_SECONDS[index]
		await _picture("table_set_aside_%d" % index)
	var strip: Object = _part("_debuffs")
	strip.call("show_debuffs", controller)
	var line: String = tr("table.set_aside").format({"cards": controller.call("set_aside_names")})
	var lines: Object = member(strip, "_lines")
	# The slip spells out each rule only when the full form fits; at the largest text sizes
	# it names the rules alone, and the set-aside line goes with the boss's rule.
	var full: bool = int(member(strip, "_form")) == DebuffStrip.Form.FULL
	var said: bool = str(lines.call("get_parsed_text")).contains(line)
	_expect(said or not full, "NO SET ASIDE ON SLIP")
	await _shot("table_set_aside_slip")
	var kitty: PackedStringArray = []
	for card: CardInstance in deal.kitty:
		kitty.append(str(card.id()))
	pile.call("clear")
	var seen: RunEvent = RunEvent.new(RunEvent.Type.KITTY_SEEN, 0, 0, 0.0, ",".join(kitty))
	beats.call("on_event", seen, false)
	_expect(bool(beats.call("kitty_shown")), "NO KITTY SEEN")
	await _shot("table_kitty_seen")
	deal.set_aside.clear()
	loop.state.boss_id = was_boss
	await _restore(snapshot)
