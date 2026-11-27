class_name AppealEffect
extends CampaignEffect
## Before the first play: this round's debuff from the Set's ladder is lifted for the
## round. It is turned off in the stack, so every hook stops at once; the next round's
## stack is built again with it. A boss's rule is not a debuff. A deal the debuff already
## changed stays dealt.


## Refuses when the round has no debuff, or it is already switched off.
func check(context: CampaignContext) -> Reason:
	var debuff: ActiveModifier = context.flags.round_debuff
	if debuff == null or not debuff.enabled:
		return Reason.NO_DEBUFF
	return Reason.OK


## Switches the round's debuff off in the stack and logs it as lifted.
func apply(context: CampaignContext) -> void:
	var debuff: ActiveModifier = context.flags.round_debuff
	context.stack.set_enabled(debuff, false)
	context.flags.lifted = debuff.definition.id
	context.add_event(
		RunEvent.new(
			RunEvent.Type.DEBUFF_LIFTED,
			context.player,
			context.state.round_index,
			0.0,
			debuff.definition.id
		)
	)
