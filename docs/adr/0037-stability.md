# ADR 0037: Logs, an exit that was not clean, and one game at a time

- Status: Accepted, 2026-11-19, by the agent. The owner judges by playtest.
- Scope: P5.4, and the hole [ADR 0022](0022-the-file-and-unofficial-builds.md) left open: two copies of the game writing one save.

## Why this needs a decision

P5.4 asks for file logging with rotation, a crash handler that preserves the last save, and a soak test of 100 full simulated runs. It does not say what is logged, what a crash handler should do when the engine does not say what is safe as it crashes, what "preserves" means when the save is already written safely, or what a simulated run must exercise to count.

## Decision

### Logs

**The engine's own file logging, set by name.** The engine already logs to a file on desktop by default. The project sets it for every platform (`debug/file_logging/enable_file_logging`), names the file `user://logs/commons.log`, and sets `debug/file_logging/max_log_files` to 10. At each launch the engine copies the last session's log to a file named with the time and starts the log again, so ten files is this session and the nine before it. That is the rotation: it bounds the number of files, not their size. No logger of the game's own.

**What the game adds to it.** One line at start: the game's version, whether the build is official, the system, the renderer and the screen size. One line each when a run starts, resumes or ends, with its seed and save schema. One line for every save or load that fails or falls back to the backup. Nothing is printed each frame or each turn.

**Nothing personal.** The log holds no family name, no path outside the game's own folder and nothing typed by the player.

### An exit that was not clean

**A session file marks a game that is open.** On a normal launch the game writes `user://session.json` with the time it started, writes the time again every few seconds while it runs, and removes the file when it closes. The engine lets a script ask whether a process is running only for a process it started itself, so the game cannot ask about another copy by its process ID. A file that keeps being written is the sign of life instead.

**A crash handler should not save, so it does not try.** The engine does send scripts a notification as it crashes, and says nothing about what is safe to do in it. The state in memory may be the thing that is broken, and writing it could replace a good save with a bad one. The save does not need it: `SaveService` writes to a temporary file, moves the save it replaces to a backup and renames the new one into place, and loading falls back to the backup, so the game stopping between any two of those steps leaves a save that loads. A power cut can still lose what the system had not yet put on the disk; the game does not force that.

**The next launch does the preserving.** If the session file is there and has gone unwritten for longer than three beats, the last session did not close. Before anything is loaded or written, the game copies the run save, its backup, the profile, the private ledger and the last session's log, which by then is the newest of the engine's dated copies, into `user://crashes/<time>/`, and keeps the newest five such folders. Then it starts as usual. The title shows one notice: the game did not close properly, the save was kept, and where the copy and the log are, with a button that opens the folder.

This covers a crash, a kill, a power cut and a frozen machine alike, which a handler inside the crashing process cannot.

### One game at a time

**If the session file is still being written, this is a second copy.** It shows a notice that the game is already open and offers Quit, which has the focus, and Open anyway. It loads and writes nothing until the player chooses.

**The notice keeps watching.** A game that crashed a moment ago leaves a file that looks alive. If the file then goes three beats without being written, the notice closes itself and the launch carries on as after an exit that was not clean.

Open anyway exists because the test is a clock: a copy that is stalled, or a system clock that was changed, can make a dead game look alive or a live one look dead. The beat and the number of beats are data.

### Tools and tests

The session file is written only on a normal launch of the game's main scene. The test run, the headless tools and the playtest never write one and are never stopped by one.

### The soak

`tools/soak.gd` plays 100 full runs headless and exits 1 on any fault. Each run:

- is played to its end by the balance harness's drivers ([ADR 0027](0027-balance-harness.md)), with the collective, private and mixed strategies taken in turn, at stakes taken in turn, with every unlock tier open;
- is saved through the real `SaveService` at every Set boundary into a folder of its own, loaded back, and resumed from that save; the resumed run must be the same run, state for state;
- counts refused commands, illegal bot actions, script errors and engine errors, save and load failures, and mismatches after a resume.

It writes `reports/soak.md` with the count of each and the seeds of any run that failed. The nightly workflow runs it. P5.4 is done when a full soak finishes with every count at zero.

## Alternatives rejected

- **Saving from the engine's crash notification.** See above: it risks the save it is meant to protect.
- **A logger of the game's own with a size cap.** The engine's rotation already bounds the number of files, and the game prints a handful of lines a session.
- **Asking the system whether the other copy's process is alive.** `OS.is_process_running` answers only for a child the game started with `OS.create_process` ([OS, Godot 4.5 class reference](https://docs.godotengine.org/en/4.5/classes/class_os.html), read 2026-11-19). A process ID would also be reused by the system in time.
- **Refusing a second copy outright.** Simple, and wrong whenever the clock test is wrong.
- **An operating-system file lock.** The engine gives scripts no portable one.
- **A soak without saves.** The balance harness already plays hundreds of runs. What it does not do is save and resume, which is where a long run's state is most likely to go wrong.

## Consequences

- A player who reports a problem can send one folder.
- The folders under `user://crashes/` hold copies of saves. Putting one back by hand is the same act as restoring any old save, and ADR 0022's rules for that are unchanged.
- The two notices are new player-facing text and go through the string table.
- A crash that happens before the session file is written leaves no trace beyond the engine's log.
- The game writes one small file every few seconds while it is open.
- A second copy started while the first is stalled for longer than three beats will take the first for dead and open. The hole of ADR 0022 is narrowed to that case and to Open anyway, not closed.

## Amendment, 2026-11-25: a save from a newer version

The owner keeps several builds on one PC. Before this amendment an older build took a save whose schema was newer than its own for a damaged one: its next write deleted the newer main file, and the write after that rotated over the newer backup, so two writes by an older build lost a newer profile's history, file and corruption, or a newer run, for good.

**A save from a newer version is not damaged, and is never deleted or written over.** `SaveService` tells the two apart: a file that parses as a save and whose `schema_version` is above this build's is from a newer version. This holds for every file that goes through `SaveService`: the run save, the profile, their backups and the temporary files they are written to before the rename, which a newer build that stopped before its rename leaves whole.

- **Loading reports it.** With the main file from a newer version, a backup this build can read loads in its place, as for a damaged main file, but its notice says the latest save is from a newer version and was kept (`save.newer_version`). With nothing this build can read, the load's status is `SaveLoad.Status.NEWER_VERSION`, with the same notice, never `UNREADABLE`. The game log says so in a line of its own.
- **It is moved aside before it could be touched.** Before this build first writes over its path, or deletes it (abandoning a run deletes the run save), the newer file is renamed beside it with `.newer_version` added: `run.json.newer_version`, `profile.json.bak.newer_version`. Each path keeps one aside, the latest: a later aside of the same path replaces it. The move is written to the game log. If the move fails, the write is refused with an error and the newer file stays where it was; a delete leaves it.
- **Nothing restores it.** This build cannot read it, and a newer build reads its own files at their own names. A player who goes back to the newer build and wants that save again puts it back by hand: delete the older build's file of that name and rename the aside to it, `run.json.newer_version` to `run.json`, in the game's folder beside the saves (`user://`). For a run save, delete `private_ledger.txt` beside it too, since the older build rewrote it with its own run's coupons and the newer build would otherwise take that number as an edit (ADR 0022); a missing ledger is nothing.

This does not reach the crash copy above, which only copies, nor ADR 0033, which is about a save from the same schema written against other content: such a save still loads, at its checkpoint. A save from an older schema still migrates as before.
