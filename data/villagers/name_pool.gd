class_name NamePool
extends Resource
## One era's given names (ADR 0028), in pinyin without tone marks, and the first
## generation it names. A pool serves from its first generation until the next pool's.

@export var id: String = ""
@export var first_generation: int = 1
@export var names: Array[String] = []
