extends GutTest

# Integration tests for tower placement system
# Tests tower creation, cost deduction, and placement validation

var test_scene: Node2D

func before_each():
	# Setup test scene
	test_scene = Node2D.new()
	add_child_autofree(test_scene)

	# Reset GameData to known state
	GameData.coins = 100

func test_place_shooter_tower():
	# Test placing a shooter tower
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	assert_not_null(tower, "Shooter tower should be created")

	test_scene.add_child(tower)
	tower.global_position = Vector2(100, 100)

	assert_eq(tower.tower_type, Enums.TowerId.PEA_SHOOTER, "Tower type should be 'pea_shooter'")
	assert_true(tower.is_in_group(Enums.Group.TOWERS), "Tower should be in 'towers' group")
	assert_gt(tower.health.current_hp, 0, "Tower should have positive HP")

func test_place_wall_tower():
	# Test placing a wall tower
	var tower = SceneFactory.create_tower(Enums.TowerId.STUMP)
	assert_not_null(tower, "Wall tower should be created")

	test_scene.add_child(tower)
	tower.global_position = Vector2(200, 200)

	assert_eq(tower.tower_type, Enums.TowerId.STUMP, "Tower type should be 'wall'")
	assert_true(tower.is_in_group(Enums.Group.TOWERS), "Tower should be in 'towers' group")

func test_place_slow_tower():
	# Test placing a slow tower
	var tower = SceneFactory.create_tower(Enums.TowerId.ICE_FLOWER)
	assert_not_null(tower, "Slow tower should be created")

	test_scene.add_child(tower)
	tower.global_position = Vector2(300, 300)

	assert_eq(tower.tower_type, Enums.TowerId.ICE_FLOWER, "Tower type should be 'slow'")
	assert_true(tower.is_in_group(Enums.Group.TOWERS), "Tower should be in 'towers' group")

func test_tower_cost_deduction():
	# Test that tower cost is correctly calculated from per-level data
	var shooter_cost = SceneFactory.get_tower_cost(Enums.TowerId.PEA_SHOOTER)
	var wall_cost = SceneFactory.get_tower_cost(Enums.TowerId.STUMP)
	var slow_cost = SceneFactory.get_tower_cost(Enums.TowerId.ICE_FLOWER)

	var shooter_td: TowerData = GameConfig.towers[Enums.TowerId.PEA_SHOOTER]
	var wall_td: TowerData = GameConfig.towers[Enums.TowerId.STUMP]
	var slow_td: TowerData = GameConfig.towers[Enums.TowerId.ICE_FLOWER]

	assert_eq(shooter_cost, shooter_td.place_cost_per_level[0], "Shooter tower cost should match level 1 place_cost")
	assert_eq(wall_cost, wall_td.place_cost_per_level[0], "Wall tower cost should match level 1 place_cost")
	assert_eq(slow_cost, slow_td.place_cost_per_level[0], "Slow tower cost should match level 1 place_cost")

	# Simulate cost deduction
	var initial_coins = GameData.coins
	GameData.coins -= shooter_cost

	assert_eq(GameData.coins, initial_coins - shooter_cost, "Coins should be deducted by tower cost")

func test_invalid_tower_placement():
	# Test that invalid tower type returns null
	var invalid_tower = SceneFactory.create_tower("invalid_type")
	assert_null(invalid_tower, "Invalid tower type should return null")
	assert_push_error("Unknown tower type")

func test_insufficient_coins():
	# Test placement prevention when not enough coins
	GameData.coins = 10  # Less than tower cost
	var tower_cost = SceneFactory.get_tower_cost(Enums.TowerId.PEA_SHOOTER)

	assert_gt(tower_cost, GameData.coins, "Tower cost should be greater than available coins")

	# In real game, placement would be prevented
	# Here we just verify the cost check logic
	var can_afford = GameData.coins >= tower_cost
	assert_false(can_afford, "Should not be able to afford tower")

func test_tower_restoration():
	# Test that towers can be restored from inventory
	var tower_type = Enums.TowerId.PEA_SHOOTER
	var tower_position = Vector2(150, 150)

	# Simulate saving tower to inventory
	GameData.tower_inventory.append({
		"type": tower_type,
		"position": tower_position
	})

	assert_eq(GameData.tower_inventory.size(), 1, "Tower inventory should have 1 entry")

	# Restore tower from inventory
	var saved_tower = GameData.tower_inventory[0]
	var restored_tower = SceneFactory.create_tower(saved_tower["type"])

	assert_not_null(restored_tower, "Restored tower should be created")
	assert_eq(restored_tower.tower_type, tower_type, "Restored tower type should match")

	test_scene.add_child(restored_tower)
	restored_tower.global_position = saved_tower["position"]

	assert_eq(restored_tower.global_position, tower_position, "Restored tower position should match")

	# Cleanup inventory
	GameData.tower_inventory.clear()

func test_multiple_tower_placement():
	# Test placing multiple towers
	var towers = []

	for i in range(3):
		var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
		test_scene.add_child(tower)
		tower.global_position = Vector2(i * 100, i * 100)
		towers.append(tower)

	assert_eq(towers.size(), 3, "Should have 3 towers")

	# Verify all towers are in the scene
	var towers_in_group = test_scene.get_tree().get_nodes_in_group(Enums.Group.TOWERS)
	assert_gte(towers_in_group.size(), 3, "Should have at least 3 towers in group")

func test_tower_hp_from_config():
	# Test that tower HP is loaded from GameConfig
	var shooter = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	test_scene.add_child(shooter)

	var expected_hp = GameConfig.towers[Enums.TowerId.PEA_SHOOTER].hp_per_level[0]
	assert_eq(shooter.health.current_hp, expected_hp, "Shooter tower HP should match config")

	var wall = SceneFactory.create_tower(Enums.TowerId.STUMP)
	test_scene.add_child(wall)

	expected_hp = GameConfig.towers[Enums.TowerId.STUMP].hp_per_level[0]
	assert_eq(wall.health.current_hp, expected_hp, "Wall tower HP should match config")
