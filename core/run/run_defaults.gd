class_name RunDefaults
extends RefCounted
## The numbers a run plays by, from data, each preloaded here under one name: the run's
## own, the plot's upgrades, the meters, Resentment, free riding, the village and its
## memory. The loop and its parts play by them, and the controller's views read them to
## show the player what a rule costs.

const PARAMS: RunParams = preload("res://data/run/default_run.tres")
const PLOT_UPGRADES: PlotUpgradeParams = preload("res://data/run/plot_upgrades.tres")
const METERS: MeterTable = preload("res://data/run/meters.tres")
const RESENTMENT: ResentmentParams = preload("res://data/run/resentment.tres")
const FREE_RIDE: FreeRideParams = preload("res://data/run/free_ride.tres")
const VILLAGE: VillageBook = preload("res://data/villagers/village.tres")
const MEMORY: MemoryParams = preload("res://data/villagers/memory.tres")
