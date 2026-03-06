extends GutTest

# Integration tests for enemy spawning system
# Tests enemy creation, configuration, and type assignment

var test_scene: Node2D

func before_each():
	# Setup test scene
	test_scene = Node2D.new()
	add_child_autofree(test_scene)

func test_spawn_normal_enemy():
	# Test spawning a normal enemy
	var enemy = SceneFactory.create_enemy("normal")
	assert_not_null(enemy, "Normal enemy should be created")

	test_scene.add_child(enemy)
	enemy.global_position = Vector2(100, 100)

	assert_eq(enemy.enemy_type, "normal", "Enemy type should be 'normal'")
	assert_true(enemy.is_in_group("enemies"), "Enemy should be in 'enemies' group")

func test_spawn_fast_enemy():
	# Test spawning a fast enemy
	var enemy = SceneFactory.create_enemy("fast")
	assert_not_null(enemy, "Fast enemy should be created")

	test_scene.add_child(enemy)
	enemy.global_position = Vector2(200, 200)

	assert_eq(enemy.enemy_type, "fast", "Enemy type should be 'fast'")
	assert_true(enemy.is_in_group("enemies"), "Enemy should be in 'enemies' group")

func test_spawn_tank_enemy():
	# Test spawning a tank enemy
	var enemy = SceneFactory.create_enemy("tank")
	assert_not_null(enemy, "Tank enemy should be created")

	test_scene.add_child(enemy)
	enemy.global_position = Vector2(300, 300)

	assert_eq(enemy.enemy_type, "tank", "Enemy type should be 'tank'")
	assert_true(enemy.is_in_group("enemies"), "Enemy should be in 'enemies' group")

func test_enemy_config_from_gameconfig():
	# Test that enemy stats are loaded from GameConfig
	var normal_enemy = SceneFactory.create_enemy("normal")
	test_scene.add_child(normal_enemy)

	var expected_hp = GameConfig.ENEMIES["normal"]["hp"]
	var expected_speed = GameConfig.ENEMIES["normal"]["speed"]
	var expected_damage = GameConfig.ENEMIES["normal"]["damage"]

	assert_eq(normal_enemy.max_hp, expected_hp, "Normal enemy max HP should match config")
	assert_eq(normal_enemy.current_hp, expected_hp, "Normal enemy current HP should equal max HP")
	assert_eq(normal_enemy.speed, expected_speed, "Normal enemy speed should match config")
	assert_eq(normal_enemy.tower_attack_damage, expected_damage, "Normal enemy damage should match config")

func test_fast_enemy_config():
	# Test fast enemy configuration
	var fast_enemy = SceneFactory.create_enemy("fast")
	test_scene.add_child(fast_enemy)

	var expected_hp = GameConfig.ENEMIES["fast"]["hp"]
	var expected_speed = GameConfig.ENEMIES["fast"]["speed"]

	assert_eq(fast_enemy.max_hp, expected_hp, "Fast enemy max HP should match config")
	assert_eq(fast_enemy.speed, expected_speed, "Fast enemy speed should match config")
	assert_gt(fast_enemy.speed, 100.0, "Fast enemy should have high speed")

func test_tank_enemy_config():
	# Test tank enemy configuration
	var tank_enemy = SceneFactory.create_enemy("tank")
	test_scene.add_child(tank_enemy)

	var expected_hp = GameConfig.ENEMIES["tank"]["hp"]
	var expected_speed = GameConfig.ENEMIES["tank"]["speed"]

	assert_eq(tank_enemy.max_hp, expected_hp, "Tank enemy max HP should match config")
	assert_eq(tank_enemy.speed, expected_speed, "Tank enemy speed should match config")
	assert_gt(tank_enemy.max_hp, 100.0, "Tank enemy should have high HP")

func test_enemy_type_is_set_correctly():
	# Test that enemy_type is correctly set for all enemy types
	var enemy_types = ["normal", "fast", "tank"]

	for type in enemy_types:
		var enemy = SceneFactory.create_enemy(type)
		assert_not_null(enemy, "Enemy of type '%s' should be created" % type)

		test_scene.add_child(enemy)
		assert_eq(enemy.enemy_type, type, "Enemy type should be '%s'" % type)

func test_invalid_enemy_type():
	# Test that invalid enemy type returns null
	var invalid_enemy = SceneFactory.create_enemy("invalid_type")
	assert_null(invalid_enemy, "Invalid enemy type should return null")
	assert_push_error("Unknown enemy type")

func test_multiple_enemy_spawning():
	# Test spawning multiple enemies
	var enemies = []

	for i in range(5):
		var enemy = SceneFactory.create_enemy("normal")
		test_scene.add_child(enemy)
		enemy.global_position = Vector2(i * 50, 100)
		enemies.append(enemy)

	assert_eq(enemies.size(), 5, "Should have 5 enemies")

	# Verify all enemies are in the scene
	var enemies_in_group = test_scene.get_tree().get_nodes_in_group("enemies")
	assert_gte(enemies_in_group.size(), 5, "Should have at least 5 enemies in group")

func test_mixed_enemy_types_spawning():
	# Test spawning different enemy types together
	var normal = SceneFactory.create_enemy("normal")
	var fast = SceneFactory.create_enemy("fast")
	var tank = SceneFactory.create_enemy("tank")

	test_scene.add_child(normal)
	test_scene.add_child(fast)
	test_scene.add_child(tank)

	normal.global_position = Vector2(100, 100)
	fast.global_position = Vector2(200, 100)
	tank.global_position = Vector2(300, 100)

	assert_eq(normal.enemy_type, "normal", "First enemy should be normal")
	assert_eq(fast.enemy_type, "fast", "Second enemy should be fast")
	assert_eq(tank.enemy_type, "tank", "Third enemy should be tank")

	# Verify different stats
	assert_lt(normal.speed, fast.speed, "Fast enemy should be faster than normal")
	assert_gt(tank.max_hp, normal.max_hp, "Tank enemy should have more HP than normal")

func test_enemy_base_speed_initialization():
	# Test that base_speed is correctly initialized
	var enemy = SceneFactory.create_enemy("normal")
	test_scene.add_child(enemy)

	assert_eq(enemy.base_speed, enemy.speed, "Base speed should equal current speed initially")
	assert_gt(enemy.base_speed, 0, "Base speed should be positive")

func test_enemy_coin_drop_config():
	# Test that coin drop values are in GameConfig
	for enemy_type in ["normal", "fast", "tank"]:
		var config = GameConfig.ENEMIES[enemy_type]
		assert_true(config.has("coin_drop_min"), "Enemy config should have coin_drop_min")
		assert_true(config.has("coin_drop_max"), "Enemy config should have coin_drop_max")
		assert_gte(config["coin_drop_max"], config["coin_drop_min"], "Max coin drop should be >= min")

func test_spawn_position_is_inside_new_map_bounds():
	var spawner = preload("res://scripts/systems/enemy_spawner.gd").new()
	for i in range(20):
		var pos = spawner.get_random_spawn_position()
		assert_lte(abs(pos.x), GameConfig.MAP_HALF_WIDTH)
		assert_lte(abs(pos.y), GameConfig.MAP_HALF_HEIGHT)
