class_name TweenWatch
extends RefCounted
## Tells a test which tweens it set off: those running now that were not among the ones it
## took before, told apart by identity, so a tween of something else that is still running
## never hides one or counts as one.


## The tweens of tree still running that were not among earlier.
static func running_since(tree: SceneTree, earlier: Array[Tween]) -> Array[Tween]:
	var running: Array[Tween] = []
	for tween: Tween in tree.get_processed_tweens():
		if tween.is_valid() and tween.is_running() and not earlier.has(tween):
			running.append(tween)
	return running
