class_name TraitShift
extends Resource
## A family trait that changes with a run meter (ADR 0043): while the meter stands in the
## band or above it, the family plays with this level of the trait in place of its own.
## Any family may carry shifts, so an expansion's family takes one with no new code.

## A meter ID, as RunMeters names them: "famine" or "denunciation".
@export var meter: String = "famine"
## The band of the meter from which the shift holds, and above.
@export var band: MeterBands.Band = MeterBands.Band.HIGH
## One of the five personality traits, as VillageDrift.TRAITS names them.
@export var trait_name: String = "honesty"
## The level the trait takes while the shift holds.
@export var level: Personality.Level = Personality.Level.LOW
## The dossier's line once the player has seen the shift at work: {count} the times seen,
## {at} the least value of the band.
@export var seen_key: String = ""
