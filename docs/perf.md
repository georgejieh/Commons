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

The GPU cost of the post-process pass alone was not isolated; P3B.7's under-1 ms check needs a GPU profiler capture.

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
