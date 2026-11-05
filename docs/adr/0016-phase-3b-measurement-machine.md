# ADR 0016: Where Phase 3B measures performance

## Status

Accepted by the project owner on 2026-11-03.

## Context

P3B.3, P3B.7 and P3B.12 must meet their budgets "on minimum spec". The minimum-spec machine isn't defined until P5.3, which is two phases later.

## Options

1. Build these items, measure them on the development PC, and leave them blocked until P5.3.
2. Define the minimum spec now, bringing P5.3's ADR forward.
3. Let the development PC stand in as minimum spec for Phase 3B.

## Choice

Option 3. Phase 3B items tick once they pass on the development PC. Each measurement is recorded with the machine it ran on.

The development PC: Intel Core i7-6700K at 4.0 GHz, NVIDIA GeForce GTX 1060 6 GB, 32 GB RAM, Windows 10 Pro 19045. This is faster than the integrated-graphics laptop P5.3 describes, especially the GPU.

## Consequences

- Phase 3B can finish without waiting on hardware.
- P5.3 still defines the real minimum spec and re-measures every budget there. A Phase 3B result that misses on that machine reopens as P5.3 work, not as a regression in Phase 3B.
