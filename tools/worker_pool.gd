class_name WorkerPool
extends RefCounted
## Runs a tool's work on worker threads, as the balance harness and the soak do: each
## worker calls work until it returns, taking its next task under the tool's own lock.
## With one job the work runs on the calling thread. Development only; tools/ never ships.


## Calls work on jobs threads at once and returns when every one has returned.
static func run(work: Callable, jobs: int) -> void:
	if jobs == 1:
		work.call()
		return
	var threads: Array[Thread] = []
	for _job: int in jobs:
		var thread: Thread = Thread.new()
		thread.start(work)
		threads.append(thread)
	for thread: Thread in threads:
		thread.wait_to_finish()
