class_name SpeechLine
extends Resource
## One thing a villager can say at the table: the event that prompts it, its string key,
## and an optional mood that later shapes the voice (P3B.13).

@export var event: String = ""
@export var text_key: String = ""
## Empty for no mood. Otherwise one of SpeechBook.MOODS.
@export var mood: String = ""
