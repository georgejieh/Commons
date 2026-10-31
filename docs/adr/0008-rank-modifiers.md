# ADR 0008: Rank modifiers

## Status

Accepted

## Context

Rank modifiers change what beats what. P1C.4 needs them to leave chains intact, and the classifier, comparator, move generator and bots must all read the same maps. Some modifiers hold for one seat or part of a trick, so a play on the table can outlive the map it was read under.

## Options

- Compare every play under the current seat's map at comparison time.
- Fix each play's strength from its own player's map, and refresh it when the maps change.

## Decision

Comparisons use effective ranks. Chain adjacency always uses base ranks, so promoting 3s never breaks a straight.

A play's strength comes from the map of the seat that played it. "Your 2s rank as 3s" and "reversed for your plays only" change your plays and nobody else's.

When a bomb changes the maps mid-trick, the round refreshes the play on the table under its player's new map. So after Cultural Revolution fires, a lower bomb beats the higher one just played. The inversion ends with the trick.

An effective-rank map is a byte per base rank. Promotion moves a rank to just above another and steps the ranks between down, so order is preserved. Maps may tie: Criticism Meeting gives 2s the same value as 3s, and the comparator's strict "higher" means neither beats the other.

A chain's strength is its lowest rank's effective value, as P1B.2 defines main rank. Under Promotion of the Masses a straight from 3 therefore beats every other straight, because its lowest rank is the promoted one. Reversal stays consistent, because order flips for every rank.

## Consequences

`SeatRules` holds one RuleSet and one map per seat, and the round asks it for the acting seat's. `Pattern.rekeyed()` exists for the refresh. The chain behavior under Promotion is a playtest question; changing it means choosing a different chain main rank, in `Pattern` construction only.
