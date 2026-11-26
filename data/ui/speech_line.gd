class_name SpeechLine
extends Resource
## One thing a villager can say at the table: the event that prompts it, its string key,
## and an optional mood that shapes the voice.

## The event that prompts it, one of SpeechBook.EVENTS.
@export var event: String = ""
## The string key of the line.
@export var text_key: String = ""
## Empty for no mood. Otherwise a key of VoiceTiming.moods.
@export var mood: String = ""
