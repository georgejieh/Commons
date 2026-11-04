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
