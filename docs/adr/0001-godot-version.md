# ADR 0001: Pin Godot 4.7.2

Status: accepted, 2026-10-30.

## Context

The checklist pins the latest stable Godot 4.x minor version. GitHub's release data shows 4.7.2-stable, published 2026-08-18, as the latest 4.x release.

## Options

- 4.7.2: latest stable, supported by the Godot AI add-on, which needs 4.7 or newer.
- An older 4.x: no benefit for a new project.

## Choice

Godot 4.7.2-stable with the Compatibility renderer, the widest hardware support and enough for 2D.

## Consequences

- Editor, export templates and the CI image must all stay on 4.7.2.
- An upgrade is a deliberate change to this ADR, CI and the release workflow together.
