# ADR 0005: Public GitHub repository for CI and releases

Status: accepted, 2026-10-30.

## Context

P0.6 and P0.8 need CI, enforced merge blocking and release hosting.

## Options

- Public repository: merge rules work on any plan, and Actions minutes are free, including macOS runners.
- Private on GitHub Free: merge rules cannot be enforced.
- Private on GitHub Pro: enforced, with limited minutes, and macOS runners use them faster.

## Choice

A public repository at `georgejieh/Commons`, default branch `main`. The source stays proprietary under ADR 0002. `docs/PLAN.md` and `docs/CHECKLIST.md` stay out of Git.

## Consequences

- Nothing with a redistribution limit goes in the repository, including raw or derived Sonniss sounds.
- A ruleset with no bypass requires pull requests and passing `lint`, `test` and `export` checks, so nobody pushes straight to `main`.
- CI uses the `barichello/godot-ci` image pinned by digest, and actions pinned by commit, so builds repeat exactly.
