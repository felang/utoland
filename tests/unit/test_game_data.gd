extends GutTest

func before_each() -> void:
	PlayerState.reset()
	PlayerProgression.reset()
	InventoryManager.reset()
	StatsTracker.reset()
	InventoryManager.deployed_weapons = []
	InventoryManager.deployed_towers = []
	PlayerProgression.player_level = 1  # 人口上限 2
	InventoryManager.coins = 100

# ===== can_buy_item =====

func test_can_buy_item_true_when_population_available() -> void:
	assert_true(InventoryManager.can_buy_item("bow", 1))

func test_can_buy_item_false_when_pop_full_no_merge() -> void:
	InventoryManager.deployed_weapons.append({id = "bow", level = 1})
	InventoryManager.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(0, 0), deploy_id = 1})
	assert_false(InventoryManager.can_buy_item("shuriken", 1))

func test_can_buy_item_false_when_pop_full() -> void:
	# 合成机制改为手动触发，人口满时无论是否有配对都不允许购买
	InventoryManager.deployed_weapons.append({id = "bow", level = 1})
	InventoryManager.deployed_weapons.append({id = "bow", level = 1})
	assert_false(InventoryManager.can_buy_item("bow", 1))

func test_can_buy_item_tower_merge_possible() -> void:
	# 合成机制改为手动触发，人口满时不允许购买
	InventoryManager.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(0, 0), deploy_id = 1})
	InventoryManager.deployed_towers.append({id = "pea_shooter", level = 1, grid_pos = Vector2i(1, 0), deploy_id = 2})
	assert_false(InventoryManager.can_buy_item("pea_shooter", 1))
