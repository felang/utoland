extends GutTest

# Integration tests for tower creation system

var test_scene: Node2D

func before_each():
	test_scene = Node2D.new()
	add_child_autofree(test_scene)
	InventoryManager.coins = 100

func test_place_shooter_tower():
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	assert_not_null(tower, "Shooter tower should be created")

	test_scene.add_child(tower)
	tower.global_position = Vector2(100, 100)

	assert_eq(tower.tower_type, Enums.TowerId.PEA_SHOOTER, "Tower type should be 'pea_shooter'")
	assert_true(tower.is_in_group(Enums.Group.TOWERS), "Tower should be in 'towers' group")
	assert_gt(tower.health.current_hp, 0, "Tower should have positive HP")

func test_place_wall_tower():
	var tower = SceneFactory.create_tower(Enums.TowerId.ICE_FLOWER)
	assert_not_null(tower, "Wall tower should be created")

	test_scene.add_child(tower)
	tower.global_position = Vector2(200, 200)

	assert_eq(tower.tower_type, Enums.TowerId.ICE_FLOWER, "Tower type should be 'wall'")
	assert_true(tower.is_in_group(Enums.Group.TOWERS), "Tower should be in 'towers' group")

func test_place_slow_tower():
	var tower = SceneFactory.create_tower(Enums.TowerId.ICE_FLOWER)
	assert_not_null(tower, "Slow tower should be created")

	test_scene.add_child(tower)
	tower.global_position = Vector2(300, 300)

	assert_eq(tower.tower_type, Enums.TowerId.ICE_FLOWER, "Tower type should be 'slow'")
	assert_true(tower.is_in_group(Enums.Group.TOWERS), "Tower should be in 'towers' group")

func test_tower_data_sell_price():
	var shooter_td: TowerData = GameConfig.towers[Enums.TowerId.PEA_SHOOTER]
	var wall_td: TowerData = GameConfig.towers[Enums.TowerId.ICE_FLOWER]
	var slow_td: TowerData = GameConfig.towers[Enums.TowerId.ICE_FLOWER]

	assert_gt(shooter_td.sell_price_per_level[0], 0, "Shooter sell price should be positive")
	assert_gt(wall_td.sell_price_per_level[0], 0, "Wall sell price should be positive")
	assert_gt(slow_td.sell_price_per_level[0], 0, "Slow sell price should be positive")

func test_invalid_tower_placement():
	var invalid_tower = SceneFactory.create_tower("invalid_type")
	assert_null(invalid_tower, "Invalid tower type should return null")
	assert_push_error("Unknown tower type")

func test_tower_restoration_from_deployed_towers():
	# 测试从 deployed_towers 恢复塔
	InventoryManager.deployed_towers = [{id = "pea_shooter", level = 1, grid_pos = Vector2i(2, 3)}]

	var tower_entry = InventoryManager.deployed_towers[0]
	var tower = SceneFactory.create_tower(tower_entry.id, tower_entry.level)

	assert_not_null(tower, "Restored tower should be created")
	assert_eq(tower.tower_type, "pea_shooter", "Restored tower type should match")
	assert_eq(tower.current_level, 1, "Restored tower level should match")

	test_scene.add_child(tower)
	# 清理
	InventoryManager.deployed_towers.clear()

func test_multiple_tower_placement():
	var towers = []

	for i in range(3):
		var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
		test_scene.add_child(tower)
		tower.global_position = Vector2(i * 100, i * 100)
		towers.append(tower)

	assert_eq(towers.size(), 3, "Should have 3 towers")

	var towers_in_group = test_scene.get_tree().get_nodes_in_group(Enums.Group.TOWERS)
	assert_gte(towers_in_group.size(), 3, "Should have at least 3 towers in group")

func test_tower_hp_from_config():
	var shooter = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	test_scene.add_child(shooter)

	var expected_hp = GameConfig.towers[Enums.TowerId.PEA_SHOOTER].hp_per_level[0]
	assert_eq(shooter.health.current_hp, expected_hp, "Shooter tower HP should match config")

	var wall = SceneFactory.create_tower(Enums.TowerId.ICE_FLOWER)
	test_scene.add_child(wall)

	expected_hp = GameConfig.towers[Enums.TowerId.ICE_FLOWER].hp_per_level[0]
	assert_eq(wall.health.current_hp, expected_hp, "Wall tower HP should match config")
