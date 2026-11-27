class_name TestWait
extends RefCounted
## Waits for what a test set off, frame by frame, and fails the test, naming what it waited
## for, when it does not come in time. A wait never ends quietly: a test goes on only once
## the thing it waits for is so.

## The longest a wait takes, in seconds of play: generous, as a headless run on a busy
## machine can go slowly.
const SECONDS: float = 10.0


## Waits until done returns true, and returns whether it did; on a timeout the test fails.
static func until(
	suite: GdUnitTestSuite, done: Callable, what: String, seconds: float = SECONDS
) -> bool:
	var tree: SceneTree = suite.get_tree()
	var waited: float = 0.0
	while not bool(done.call()):
		if waited >= seconds:
			suite.fail("Waited %.1f s for %s" % [seconds, what])
			return false
		await tree.process_frame
		waited += suite.get_process_delta_time()
	return true


## Waits until read gives the same value two frames running, as a motion does once it has
## come to rest, and returns whether it did; on a timeout the test fails. A motion that has
## not begun holds still too, so start it, or wait for it to start, first.
static func still(
	suite: GdUnitTestSuite, read: Callable, what: String, seconds: float = SECONDS
) -> bool:
	var last: Array = [null]
	var held: Callable = func() -> bool:
		var now: Variant = read.call()
		var same: bool = now == last[0]
		last[0] = now
		return same
	return await until(suite, held, what, seconds)
