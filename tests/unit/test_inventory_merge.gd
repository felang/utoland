extends GutTest

func before_each() -> void:
	PlayerState.reset()
	PlayerProgression.reset()
	InventoryManager.reset()
	StatsTracker.reset()
	InventoryManager.coins = 100
	PlayerProgression.player_level = 10

# ===== _check_merge 二合一（塔） =====

func test_check_merge_towers_preserves_position() -> void:
	InventoryManager.deployed_towers = [
		{id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = 1},
		{id = "pea_shooter", level = 1, grid_pos = Vector2i(10, 10), deploy_id = 2},
	]
	InventoryManager._check_merge("pea_shooter", 1)
	assert_eq(InventoryManager.deployed_towers.size(), 1)
	assert_eq(InventoryManager.deployed_towers[0].level, 2)

func test_check_merge_no_merge_with_one_tower() -> void:
	InventoryManager.deployed_towers = [
		{id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = 1},
	]
	InventoryManager._check_merge("pea_shooter", 1)
	assert_eq(InventoryManager.deployed_towers.size(), 1)
	assert_eq(InventoryManager.deployed_towers[0].level, 1)

func test_check_merge_max_level_tower() -> void:
	InventoryManager.deployed_towers = [
		{id = "pea_shooter", level = 3, grid_pos = Vector2i(5, 5), deploy_id = 1},
		{id = "pea_shooter", level = 3, grid_pos = Vector2i(10, 10), deploy_id = 2},
	]
	InventoryManager._check_merge("pea_shooter", 3)
	assert_eq(InventoryManager.deployed_towers.size(), 2)

# ===== merge_tower 手动合成 =====

func test_merge_tower_success() -> void:
	InventoryManager.deployed_towers = [
		{id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = 1},
		{id = "pea_shooter", level = 1, grid_pos = Vector2i(10, 10), deploy_id = 2},
	]
	var result: bool = InventoryManager.merge_tower(1)
	assert_true(result)
	assert_eq(InventoryManager.deployed_towers.size(), 1)
	assert_eq(InventoryManager.deployed_towers[0].level, 2)
	assert_eq(InventoryManager.deployed_towers[0].deploy_id, 1)
	assert_eq(InventoryManager.deployed_towers[0].grid_pos, Vector2i(5, 5))

func test_merge_tower_no_pair() -> void:
	InventoryManager.deployed_towers = [
		{id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = 1},
		{id = "ice_flower", level = 1, grid_pos = Vector2i(10, 10), deploy_id = 2},
	]
	var result: bool = InventoryManager.merge_tower(1)
	assert_false(result)
