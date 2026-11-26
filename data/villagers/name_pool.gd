class_name NamePool
extends Resource
## One era's given names (ADR 0028), in pinyin without tone marks, and the first
## generation it names. A pool serves from its first generation until the next pool's.

## The pool's ID.
@export var id: String = ""
## The first generation the pool serves.
@export var first_generation: int = 1
## The given names, in pinyin without tone marks.
@export var names: Array[String] = []
