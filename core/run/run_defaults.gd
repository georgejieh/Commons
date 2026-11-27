class_name RunDefaults
extends RefCounted
## The numbers a run plays by, from data, each preloaded here under one name: the run's
## own, the plot's upgrades, the meters, Resentment, free riding, the village and its
## memory. The loop and its parts play by them, and the controller's views read them to
## show the player what a rule costs.

## The run's own numbers.
const PARAMS: RunParams = preload("res://data/run/default_run.tres")
## The plot upgrades' prices and limits.
const PLOT_UPGRADES: PlotUpgradeParams = preload("res://data/run/plot_upgrades.tres")
## The Famine and Denunciation meters' bands and death thresholds.
const METERS: MeterTable = preload("res://data/run/meters.tres")
## How Resentment is raised and capped, and what it turns into.
const RESENTMENT: ResentmentParams = preload("res://data/run/resentment.tres")
## The numbers of free riding.
const FREE_RIDE: FreeRideParams = preload("res://data/run/free_ride.tres")
## The village's families and youth, and how many opponents sit each Set.
const VILLAGE: VillageBook = preload("res://data/villagers/village.tres")
## The weights of what the village remembers of the player.
const MEMORY: MemoryParams = preload("res://data/villagers/memory.tres")
