class_name WorkTeamTalk
extends Resource
## What villagers say about the work team's visit (ADR 0022), in a run that began with an
## entry in the family's file. The lines ride one of the table's speech moments: each time
## a villager would say a line for event, the table draws on its own seeded stream and,
## at chance, says one of these in its place. A run with no entry draws nothing.

## The speech moment the lines ride, one of SpeechBook.EVENTS.
@export var event: String = "pass"
## The chance, 0 to 1, that a line for event is one of these instead.
@export_range(0.0, 1.0) var chance: float = 0.04
## The name the table's stream is seeded under, with the Year and the Quota.
@export var stream: String = "work_team:%d:%d"
@export var lines: Array[SpeechLine] = []
