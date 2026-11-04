class_name DemoParams
extends Resource
## The demo's run (ADR 0017): one Year, and the two villagers at the table.

@export var sets: SetParams
## BotConfig.Tier per seat; the player's entry is unused.
@export var tiers: Array[int] = [1, 1, 2]
## Display name keys per seat.
@export var name_keys: Array[String] = ["seat.you", "villager.wang", "villager.zhao"]
## Portrait per seat; the player's entry is unused.
@export var portraits: Array[Texture2D] = []
## The most need a declaration may claim.
@export var need_cap: int = 40
## Coupons at the start, so the first store visit has something to buy.
@export var starting_coupons: int = 4
