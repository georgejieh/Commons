class_name SessionParams
extends Resource
## How the game tells an open copy from one that stopped (ADR 0037).

## Seconds between two writes of the session file while the game runs.
@export var beat_seconds: float = 5.0
## Beats the session file may go unwritten before the copy that wrote it counts as gone.
@export var stale_beats: int = 3
## Folders under user://crashes/ kept, the newest first.
@export var crash_folders_kept: int = 5


## Seconds the session file may go unwritten while its copy still counts as open.
func stale_after() -> float:
	return beat_seconds * stale_beats
