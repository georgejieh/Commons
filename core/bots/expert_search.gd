class_name ExpertSearch
extends RefCounted
## Determinized sampling: deals the unseen cards consistently with what is public, rolls
## out the top candidates on each deal with the Medium policy, and picks the best average.
## Hard searches only in the endgame. A pure job, so a runner may spread it over threads.


static func applies(view: SeatView, config: BotConfig) -> bool:
	if config.tier == BotConfig.Tier.EXPERT:
		return true
	if config.tier != BotConfig.Tier.HARD:
		return false
	var left: int = 0
	for size: int in view.public.remaining:
		left += size
	return left <= config.weights.endgame_cards


## Runs a job's samples in turn, stopping if the deadline passes.
static func run(job: BotSearchJob, budget: BotBudget) -> BotPlay:
	if not job.is_ready():
		return job.fallback
	for sample: int in job.sample_count():
		if budget.is_expired():
			return job.fallback
		job.run_sample(sample)
	return job.fallback if budget.is_expired() else job.best()


## The policy's own play first, so ties keep it, then a pass when one is allowed, then the
## moves the policy's gates leave open, by hand left. A search never reopens a gate.
static func top_candidates(
	position: BotPosition, legal: Array[Pattern], policy_play: BotPlay
) -> Array[Pattern]:
	var top: Array[Pattern] = [policy_play.pattern]
	var moves: Array[Pattern] = legal
	if position.view.public.current_play != null:
		moves = FollowPolicy.open_moves(position, legal)
		_add_new(top, Pattern.pass_play())
	var spite: float = FollowPolicy.spite(position)
	var scored: Array[Array] = []
	for move: Pattern in moves:
		scored.append([position.scorer.score_play(move) + spite, move])
	scored.sort_custom(_scores_higher)
	for entry: Array in scored:
		if top.size() >= position.config.search_candidates():
			break
		_add_new(top, entry[1])
	return top


## Returns 1 if the seat's side wins this move on this deal.
static func roll(position: BotPosition, hands: Array[PackedByteArray], move: Pattern) -> int:
	var copies: Array[PackedByteArray] = []
	for hand: PackedByteArray in hands:
		copies.append(hand.duplicate())
	var view: SeatView = position.view
	var rollout: Rollout = Rollout.new(
		copies,
		view.public.landlord,
		position.seat,
		view.public.current_play,
		position.trick_owner(),
		position.passes_on_table(),
		position.table,
		position.config.rollout_config()
	)
	rollout.step(move)
	var winner: int = rollout.play_out(position.config.weights.search_step_limit)
	var landlord_won: bool = winner == view.public.landlord
	return 1 if winner != Seats.NONE and landlord_won == position.is_landlord() else 0


## Deals the unseen cards to the other seats by hand size. The landlord keeps the unplayed
## kitty. Returns nothing if the counts can't fit, which plot cards can cause.
static func deal_unseen(position: BotPosition, sample: int) -> Array[PackedByteArray]:
	var view: SeatView = position.view
	var pool: PackedByteArray = PackedByteArray()
	for rank: int in Ranks.COUNT:
		for _copy: int in position.unseen[rank]:
			pool.append(rank)
	var hands: Array[PackedByteArray] = []
	for _seat: int in Seats.COUNT:
		var empty: PackedByteArray = PackedByteArray()
		empty.resize(Ranks.COUNT)
		hands.append(empty)
	hands[position.seat] = view.own_counts.duplicate()
	if not position.is_landlord():
		_give_kitty(position, pool, hands[view.public.landlord])
	var stream: RandomStream = RandomStream.new(_sample_seed(position, sample))
	for seat: int in Seats.COUNT:
		if (
			seat != position.seat
			and not _fill(hands[seat], view.public.remaining[seat], pool, stream)
		):
			return []
	return hands


static func _fill(
	hand: PackedByteArray, size: int, pool: PackedByteArray, stream: RandomStream
) -> bool:
	var needed: int = size
	for rank: int in Ranks.COUNT:
		needed -= hand[rank]
	if needed < 0 or needed > pool.size():
		return false
	for _card: int in needed:
		var pick: int = stream.next_int(0, pool.size() - 1)
		hand[pool[pick]] += 1
		pool.remove_at(pick)
	return true


static func _give_kitty(
	position: BotPosition, pool: PackedByteArray, hand: PackedByteArray
) -> void:
	var view: SeatView = position.view
	var kept: PackedByteArray = view.public.kitty_counts.duplicate()
	for play: PublicPlay in view.public.history:
		if play.seat == view.public.landlord and play.pattern.type != Pattern.Type.PASS:
			for rank: int in Ranks.COUNT:
				kept[rank] -= mini(kept[rank], play.counts[rank])
	for rank: int in Ranks.COUNT:
		for _copy: int in kept[rank]:
			var at: int = pool.find(rank)
			if at >= 0:
				pool.remove_at(at)
				hand[rank] += 1


static func _sample_seed(position: BotPosition, sample: int) -> int:
	var view: SeatView = position.view
	var state: int = CountKey.encode(view.own_counts) ^ (view.public.history.size() << 8)
	return position.config.search_seed ^ state ^ (sample * RandomStreams.FNV_PRIME)


static func _add_new(moves: Array[Pattern], move: Pattern) -> void:
	for other: Pattern in moves:
		if other.equals(move):
			return
	moves.append(move)


static func _scores_higher(first: Array, second: Array) -> bool:
	return first[0] > second[0]
