extends GutTest

func before_each() -> void:
	PlayerState.reset()
	PlayerProgression.reset()
	InventoryManager.reset()
	StatsTracker.reset()
	InventoryManager.deployed_towers = []
	PlayerProgression.player_level = 1
	InventoryManager.coins = 100
