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
