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
