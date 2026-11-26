# Performance measurements

Each measurement names its machine and the command that produced it. Phase 3B measures on the development PC, which stands in for minimum spec until P5.3 ([ADR 0016](adr/0016-phase-3b-measurement-machine.md)).

## 2D table (P3B.3)

Machine: Intel Core i7-6700K, NVIDIA GeForce GTX 1060 6 GB, 32 GB RAM, Windows 10 Pro 19045, Compatibility renderer, vsync on. Date: 2026-11-03.

```bash
godot --path . --script res://tools/table_perf.gd -- --seconds 40
```

A seeded Set played by bot at the table's real pacing until the Set ended (1,613 frames):

| Measure | Result |
| --- | --- |
| Mean frame time | 16.67 ms (60.0 fps) |
| Median frame time | 16.67 ms |
| p99 frame time | 16.73 ms |
| Scene nodes while a round is in play | 576 at every sample, so no node is made during a round |

### With the art pass and the print post-process (P3B.7)

Same machine and command, after the GPT Image art and the full-screen post-process shader (1,606 frames):

| Measure | Result |
| --- | --- |
| Mean frame time | 16.67 ms (60.0 fps) |
| Median frame time | 16.66 ms |
| p99 frame time | 17.72 ms |
| Scene nodes while a round is in play | 758 at every sample |

The GPU cost of the post-process pass alone is isolated in the P3B.7 section below.

### 54-card stress case and the 80-view pool (P3B.3)

Same machine, 2026-11-04. The pool is 80 views, not the checklist's 60: a full 20-card hand plus a long play in each of the three lanes needs more than 60.

```bash
godot --path . --script res://tools/table_perf.gd -- --seconds 20 --stress
```

All 54 deck cards bound to pooled views on the table at once, each moved every frame (1,201 frames):

| Measure | Result |
| --- | --- |
| Mean frame time | 16.66 ms (60.0 fps) |
| p99 frame time | 17.08 ms |
| Scene nodes | 807 at every sample |

The normal 40-second Set on the same build: mean 16.66 ms (60.0 fps), p99 16.85 ms, 806 nodes at every sample while a round was in play.

## Post-process GPU cost (P3B.7)

Same machine, 2026-11-04. The tool times the GPU each frame with the viewport's render timer (`RenderingServer.viewport_get_measured_render_time_gpu`) while a seeded Set plays. It turns the pass on and off every 60 frames, skips 5 frames after each switch, and takes the difference of the medians.

```bash
godot --path . --script res://tools/table_perf.gd -- --seconds 30 --post-ab
```

Five 30-second runs of each version of the screen sampler, in ms of GPU time per frame:

| Screen texture | Run 1 | Run 2 | Run 3 | Run 4 | Run 5 | Median |
| --- | --- | --- | --- | --- | --- | --- |
| `filter_linear_mipmap` (before) | 0.962 | 0.745 | 0.364 | 0.924 | 0.748 | 0.748 |
| `filter_linear` (shipped) | 0.759 | 0.219 | 0.223 | 1.015 | 0.221 | 0.223 |

The pass never samples a lower mip, so building mipmaps of the screen copy each frame was wasted work. Dropping them changes nothing on screen.

Runs 1 and 4 of the shipped version had pass-off baselines of 0.85 ms and 3.26 ms, against about 0.65 ms in the other runs. That points to the GPU running at lower clocks for the whole run, not to the pass. Run 4, at those low clocks, measured 1.015 ms, just over budget. P5.3 re-measures on the real minimum-spec machine.

## Dread layers GPU cost (P3B.12)

Same machine, 2026-11-04. The table is held still at its worst board state: both meters at 90 and the last corruption stage. Horror intensity switches between 0 and 1 every 60 frames, with the print pass on throughout.

```bash
godot --path . --script res://tools/table_perf.gd -- --seconds 30 --horror-ab
```

| Run | 1 | 2 | 3 | 4 | 5 | Median |
| --- | --- | --- | --- | --- | --- | --- |
| Dread layers, ms of GPU per frame | 0.093 | 0.064 | 0.048 | -0.160 | 0.046 | 0.048 |

Run 4 ran at low GPU clocks (a 5.2 ms baseline), and its negative difference is noise. Together with the print pass (median 0.223 ms), the full-screen work costs about 0.27 ms, inside P3B.7's 1 ms budget.

## Texture memory (P3C.4)

`tools/texture_budget.gd` loads a seeded run on the table with every Cadre slot filled and reads the profiler's texture-memory monitor (`Performance.RENDER_TEXTURE_MEM_USED`). It runs in the cloud playtest (software OpenGL under xvfb) and fails the step when over the 128 MB budget.

| Build | Texture memory | Result |
| --- | --- | --- |
| Before (every asset at full size) | 170.4 MB | Over |
| Large art capped at 512 px on import, icons packed into one atlas | 89.2 MB | Pass |
| 18 more Cadres with art (P4.11h), Cadre art capped at 384 px | 125.0 MB peak | Pass |
| Cadre and ending pictures loaded on demand (P4.14), 18 ending pictures added | 114.3 MB peak | Pass |

The art library preloads backdrops, paper and card art. Cadre and ending pictures load only when shown, through a cache of 12 (P4.14), so the table holds just the Cadres on its board. Stage versions load only when shown, so since the stage art arrived the tool also shows all 54 card faces and measures at stages 0, 4 and 9 in turn, reporting the peak.

## Table light GPU cost (P3C.6)

`table_perf.gd --light-ab` switches the table's one `PointLight2D` on and off every 60 frames during play and compares the GPU time per frame, the P3B.7 method. It ran on the development PC (ADR 0016) with its window on the second monitor (`--screen 1`), five runs of 30 seconds.

| Run | GPU on (ms) | GPU off (ms) | Light cost (ms) |
| --- | --- | --- | --- |
| 1 | 1.003 | 0.737 | 0.266 |
| 2 | 1.029 | 0.750 | 0.279 |
| 3 | 1.007 | 0.746 | 0.261 |
| 4 | 1.890 | 1.495 | 0.395 |
| 5 | 1.016 | 0.753 | 0.263 |

The median cost is 0.266 ms, inside the 1 ms budget. Run 4 was taken while the GPU sat at a lower clock state, which doubled its baseline, as in P3B.7. Every run held 60 fps with a p99 frame time of 17.2 ms or less. The four normal maps add about 8 MB of texture memory, which leaves the full table near 97 MB of the 128 MB budget.

## Expert decision time (P4.16, ADR 0030)

Development PC (ADR 0016), 2026-11-15. The live game asks an Expert villager for its play through `ExpertRunner`, which spreads the samples over the worker pool and starts no more after the deadline in `BotWeights.expert_deadline_usec` (300 ms).

```bash
godot --headless --path . --script res://tools/expert_deadline.gd -- --deals 40 --seed 0
```

| Path | Decisions | Mean | Worst or p99 | Samples finished, of 48 |
| --- | --- | --- | --- | --- |
| `ExpertRunner` at the 300 ms deadline | 601 | not recorded | p99 352.9 ms | mean 32.2; all 48 in 206 decisions; fewest 6 |
| `Bot.decide_play` with no limit, one thread | 40 | 889 ms (median 632 ms) | worst 3,796 ms | all 48 |

The 40-deal run took 166 seconds and Expert beat Hard in 0.525 of 80 games with no illegal action. The p99 is inside P2.9's 400 ms budget. A decision that finishes fewer than 12 samples keeps the policy's play (`expert_min_samples`), so some decisions at the deadline are not searched at all.

The unlimited figures were taken over seeds 0 to 4 of `SelfPlay.deal_from_seed`, with Expert as landlord on even seeds and as both peasants on odd ones, Hard in the other seats, timing only decisions that had a choice to search. That path is what tests, the tournament and the balance harness use, and what the game used before ADR 0030.

The wait is still on the thread that handles the player's command, so a play can be followed by two deadlines before the player's next turn. P5.0 moves it off that thread.

## Expert decisions off the command thread (P5.0, ADR 0030)

Development PC (ADR 0016), 2026-11-17, 8 logical processors, so the search has 7 worker threads.

### Frames while two Expert families think

`tests/integration/test_search_frames.gd` runs the run controller in the scene tree, as the game does, with both villagers Expert, and times every frame that passes while a search is out. It runs headless with no table drawn, so it measures the loop and the scripts and not the renderer.

| Run | Searches | Frames while thinking | Longest frame | Search time, median | Search time, slowest |
| --- | --- | --- | --- | --- | --- |
| Full suite, before the hard stop | not recorded | not recorded | 14.4 ms | 311 ms | 367 ms |
| Full suite, with the hard stop | 41 | 1,270 | 7.0 ms | 310 ms | 365 ms |

The budget is 50 ms a frame. The longest frame that handed a play back to the loop took 6.9 ms.

### Decision time at the deadline

```bash
godot --headless --path . --script res://tools/expert_deadline.gd -- --deals 1000 --seed 0
godot --headless --path . --script res://tools/expert_deadline.gd -- --deals 1000 --seed 0 --wild 1
```

The first full run found the p99 over P2.9's 400 ms. The deadline stopped new samples from starting, and a sample already running finished however long it took.

| 1,000 deals, before the hard stop | Expert against Hard | Illegal actions | p99 | Searched decisions | Samples finished, of 48 |
| --- | --- | --- | --- | --- | --- |
| No wild rank | 0.525 of 2,000 games | 0 | 401.0 ms | 16,407 | mean 26.6; all 48 in 3,861; fewest 2 |
| One wild rank | 0.528 of 2,000 games | 0 | 426.1 ms | 11,222 | mean 25.7; all 48 in 2,897; fewest 0 |

A sample now has `expert_grace_usec` (60 ms) past the deadline, and is then abandoned between two steps of its rollout. The same command with `--deals 400` measured it:

| 400 deals, with the hard stop | Expert against Hard | Illegal actions | p99 | Searched decisions | Samples finished, of 48 |
| --- | --- | --- | --- | --- | --- |
| No wild rank | 0.519 of 800 games | 0 | 363.0 ms | 6,561 | mean 27.5; all 48 in 1,622; fewest 1 |
| One wild rank | 0.530 of 800 games | 0 | 372.7 ms | 4,547 | mean 23.7; all 48 in 1,043; fewest 0 |

Both are inside the 400 ms budget. The p99 sits a little past the 360 ms ceiling on samples because the figure also covers building the search and choosing among the results. Expert stays ahead of Hard both ways. The runs after the stop are 400 deals and not 1,000, so their win rates are less exact than the first table's: over 800 games one standard error is about 0.018.

Part of the first no-wild run shared the machine with other work, which may have raised its p99. The wild run and both runs after the stop had the machine to themselves.

## Every budget, by one command (P5.3, ADR 0036)

```bash
godot --headless --path . --script res://tools/perf_budget.gd -- --out reports/perf_budget.md
godot --path . --script res://tools/perf_budget.gd -- --windowed-rows --out reports/perf_budget.md
```

The first line measures the rows that need no window. The second, in a window, adds startup, frame time, node instancing and resident memory with the table open. The report names the machine and gives each row a verdict; a row that was not measured says so and is never a pass.

### Stand-in: the development PC

This is not a minimum-spec machine (ADR 0036). Intel Core i7-6700K, 8 logical processors, 32 GB, Windows 10, headless, seed 0, commit `a997c15` plus the tool, 2026-11-19.

| Row | Budget | Measured | Result | Samples |
| --- | --- | --- | --- | --- |
| Hand classification | under 50 us a call | median 8 us, p99 20 us, worst 85 us | Pass, judged on p99 | 20,000 calls |
| Legal moves, 20-card hand | median under 1 ms | median 0.17 ms, p99 1.25 ms | Pass | 2,000 hands |
| Bot decision, Easy | median under 30 ms, p99 under 100 ms | median 0.21 ms, p99 0.55 ms | Pass | 2,363 decisions |
| Bot decision, Medium | the same | median 0.40 ms, p99 3.02 ms | Pass | 1,674 decisions |
| Bot decision, Hard | the same | median 0.59 ms, p99 3.56 ms | Pass | 1,789 decisions |
| Bot decision, Expert | p99 under 400 ms | p99 355 ms, on 7 worker threads | Pass | 618 decisions over 20 deals |
| Save file size | under 64 KB | 5.8 KB | Pass | the largest autosave of a run of 8 Sets |
| Save time | under 50 ms | median 8.1 ms, worst 13.3 ms | Pass | 40 repetitions |
| Load time, the file | under 50 ms | median 4.5 ms, worst 6.0 ms | Pass | 40 repetitions |
| Resume time | none | median 101 ms, worst 133 ms | Reported | 40 repetitions |
| Run reads per table event | p99 under 200 us | median 7 us, p99 23 us | Pass | 2,000 events |
| Static memory, run loaded | none of its own | 100 MB | Reported | once |
| Resident memory, headless | under 512 MB | 194 MB | Pass, as a floor | once |
| Startup to title | under 5 s | not measured | Not measured | needs a window |
| Frame time during play | under 16.6 ms | not measured | Not measured | needs a window |
| Nodes made during a round | none | not measured | Not measured | needs a window |
| Resident memory, table open | under 512 MB | not measured | Not measured | needs a window |

Notes on what the figures cover:

- **Resume time** is what the Continue button costs: the file is loaded, then the run's record is replayed to where it was. It grows with the run; this run ended after 8 Sets of a possible 24. The budget's "load" is read here as the file, so this row has no verdict.
- **Run reads per table event** is what an event that redraws the table's status, its small ledger and the room's dread costs the screens in reads of the run, on the largest save of the played run resumed. They read it through the controller's `RunView`; when each took a whole copy of the state (`state_copy()`, two an event) the same row measured a median of 889 us and a p99 of 1.9 ms on this machine (2026-11-25), so the threshold sits far between the two.
- **Resident memory, headless** is the process's working set with no window and no textures on a GPU, so it is a floor. The figure that answers the budget is the windowed one.
- **Expert** is a short sample. The long measurements are in the section above.
- **Legal moves** is judged on the median, as the budget says. The p99 of 1.25 ms is over 1 ms.

The windowed rows have not been run on any machine. Their code was written from `tools/table_perf.gd` and compiles; nothing may open a window on the owner's screen, so the first run of them is the owner's, on a reference machine.
