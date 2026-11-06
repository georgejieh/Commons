# ADR 0012: What a Set summary counts

## Status

Accepted by the project owner on 2026-11-04, with the triggers as proposed.

## Context

P3A.7 folds each Set's events into a summary that counts, per villager, how often they were fed, bombed, denounced and betrayed. Villager memory (P4.6), epilogues (P4.13) and the New Landlord (P4.7) read only these summaries. The Plan says villagers remember "what you did to them", and that a family "whose member you bombed" sends a hostile heir. Neither document says what event counts as feeding, denouncing or betraying.

## Options

1. Count only what the player does to each villager, from events the game already has.
2. Count what every seat does to every other seat. That makes a summary per pair of seats, which nothing reads yet.
3. Leave the counts undefined until P4.6 needs them. P3A.7 can't then show that summaries match a recount.

## Choice

Option 1, with these triggers. Each one counts against the villager's family, from the table's seat-to-family mapping.

| Count | Trigger |
| --- | --- |
| Bombed | The player plays a bomb or rocket on a play the villager holds on the table |
| Betrayed | The player, as a peasant, beats a play their teammate holds |
| Fed | The player and the villager are both peasants, the player banked something into the Commons that round, and the villager's share is above zero |
| Denounced | A caught lie about need (P4.3). Nothing produces it yet, so it stays 0 |

A bomb on the teammate's play counts as both bombed and betrayed.

## Consequences

- Summaries stay small: four counts per family per Set.
- If P4.6 needs what villagers do to each other, the summary grows a second key, and this ADR is superseded.
- Changing a trigger changes `SummaryFold` and the recount in its test, and nothing else.
