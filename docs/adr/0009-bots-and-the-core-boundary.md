# ADR 0009: Bots and the core boundary

## Status

Accepted

## Context

Bots live in `core/`, which bans engine singletons and must run headless. P2.1 and P2.9 ask for three things that normally use one: a time budget, a worker thread pool, and rationale strings in debug builds only.

## Options

- Allow `Time`, `WorkerThreadPool` and `OS` in `core/bots/`. Simple, but it breaks the layer rule and makes bot decisions depend on the machine.
- Move the bots out of `core/`. They could then not be tested as pure logic.
- Keep bots pure and pass in what they need from outside.

## Decision

Bots stay pure.

**Time.** `BotBudget` holds a deadline and an injected clock `Callable`. `game/` and `tools/` supply a real clock, and tests supply a fake one. A budget with no clock never expires, so decisions without a deadline are repeatable.

**Threads.** `ExpertSearch` is a pure function over a job. A runner in `game/bots/` dispatches jobs on the worker pool and enforces the deadline, and `core/` never sees a thread.

**Rationale.** GDScript has no conditional compilation, and an exported script keeps its string constants, so a string behind a debug check would still ship. Bots return an integer `BotRationale` code. The readable text lives in `tools/bot_rationale_text.gd`, and exports exclude `tools/`, so a release build cannot contain it. This differs from the checklist's "rationale string": the bot returns the code, and a debug tool turns it into the string.

## Consequences

An expired deadline can change a decision, so only callers that pass a real clock can lose determinism. Harnesses that must replay exactly pass no clock. Every new `BotRationale` code needs a line in the text table, and a test enforces that.
