# ADR 0002: Proprietary license

Status: accepted, 2026-10-30.

## Context

Commons is a free game with a Ko-fi donation button. The repository is public because CI and releases run on GitHub. Its code, art and thesis should not be reusable as a paid clone.

## Options

- Proprietary: all rights reserved, free to download and play.
- MIT: anyone may reuse and sell the code.
- GPL-3.0: reuse allowed, and derivatives must stay GPL.

## Choice

Proprietary.

## Consequences

- Public source is visible but not open source.
- Shipped add-ons must be permissively licensed (MIT, Apache-2.0, BSD, CC0). No GPL in shipped code.
- A donation button may count as earning money, so no NC-licensed assets are used.
