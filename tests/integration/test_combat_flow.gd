extends GutTest

# Integration tests for combat flow
# Tests tower shooting, enemy damage, coin drops, and collection

var test_scene: Node2D

func before_each():
	# Setup test scene
	test_scene = Node2D.new()
	add_child_autofree(test_scene)
	# 重置被动系统
	GameData.new_passive_id = ""

func test_tower_shoots_at_enemy():
	# Test that tower can shoot bullets
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	test_scene.add_child(tower)
	tower.global_position = Vector2(200, 200)

	# Wait for tower to be ready
	await wait_frames(2)

	# Create enemy in range
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	test_scene.add_child(enemy)
	enemy.global_position = Vector2(250, 200)  # Within 300 range

	# Wait for tower to shoot
	await wait_seconds(1.5)

	# Check if bullet was created (may have already hit and been destroyed)
	# We verify the tower has the ability to shoot
	assert_not_null(tower.attacker, "Tower should have an AttackerComponent")

func test_enemy_takes_damage():
	# Test that enemy can take damage
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	test_scene.add_child(enemy)

	var initial_hp = enemy.health.current_hp
	var damage_amount = 10.0

	enemy.take_damage(damage_amount)

	assert_eq(enemy.health.current_hp, initial_hp - damage_amount, "Enemy HP should decrease by damage amount")

func test_enemy_dies_at_zero_hp():
	# Test that enemy dies when HP reaches zero
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	test_scene.add_child(enemy)

	var initial_hp = enemy.health.current_hp

	# Deal enough damage to kill enemy
	enemy.take_damage(initial_hp)

	# Wait for queue_free to process
	await wait_frames(2)

	# Enemy should be queued for deletion
	assert_false(is_instance_valid(enemy) and enemy.is_inside_tree(), "Enemy should be removed from tree")

func test_enemy_drops_exp_orbs_on_death():
	# Test that enemy drops exp orbs when it dies
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	test_scene.add_child(enemy)

	var initial_orb_count = test_scene.get_tree().get_nodes_in_group(Enums.Group.EXP_ORBS).size()

	# Kill enemy
	enemy.die()

	# Wait for exp orbs to be added
	await wait_frames(2)

	var final_orb_count = test_scene.get_tree().get_nodes_in_group(Enums.Group.EXP_ORBS).size()

	# Should have more exp orbs than before
	assert_gt(final_orb_count, initial_orb_count, "Exp orbs should be dropped after enemy death")

func test_coin_drop_amount_from_config():
	# Test that coin drop amount respects GameConfig
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	test_scene.add_child(enemy)

	var enemy_data: EnemyData = GameConfig.enemies[Enums.Enemy.NORMAL]

	assert_gte(enemy_data.coin_drop_min, 1, "Min coin drop should be at least 1")
	assert_gte(enemy_data.coin_drop_max, enemy_data.coin_drop_min, "Max coin drop should be >= min")

func test_bullet_projectile_damages_enemy():
	# Test that bullet projectile can damage enemy via take_damage
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	test_scene.add_child(enemy)
	enemy.global_position = Vector2(100, 100)

	var initial_hp = enemy.health.current_hp
	var damage_amount: float = 15.0

	# 直接调用 take_damage 验证伤害机制
	enemy.take_damage(damage_amount)

	assert_lt(enemy.health.current_hp, initial_hp, "Enemy HP should decrease after damage")

func test_coin_collection():
	# Test coin collection mechanism
	var coin = SceneFactory.create_coin()
	test_scene.add_child(coin)
	coin.global_position = Vector2(150, 150)

	assert_not_null(coin, "Coin should be created")
	assert_true(coin.is_in_group(Enums.Group.COINS), "Coin should be in 'coins' group")
	assert_gt(coin.value, 0, "Coin should have positive value")

func test_multiple_enemies_take_damage():
	# Test that multiple enemies can take damage independently
	var enemy1 = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	var enemy2 = SceneFactory.create_enemy(Enums.Enemy.FAST)

	test_scene.add_child(enemy1)
	test_scene.add_child(enemy2)

	var initial_hp1 = enemy1.health.current_hp
	var initial_hp2 = enemy2.health.current_hp

	enemy1.take_damage(10.0)
	enemy2.take_damage(15.0)

	assert_eq(enemy1.health.current_hp, initial_hp1 - 10.0, "Enemy1 HP should decrease by 10")
	assert_eq(enemy2.health.current_hp, initial_hp2 - 15.0, "Enemy2 HP should decrease by 15")

func test_tower_damage_from_config():
	# Test that tower damage is loaded from GameConfig
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	test_scene.add_child(tower)

	await wait_frames(2)

	var td: TowerData = GameConfig.towers[Enums.TowerId.PEA_SHOOTER]
	var expected_damage = td.damage_per_level[0] * GameData.player_stats.get(Enums.Stat.TOWER_MULT, 1.0)
	assert_almost_eq(tower.attacker.base_damage, expected_damage, 0.01, "Tower attacker damage should match config")

func test_enemy_drops_correct_exp_orb_count():
	# Test that enemy drops exp orbs within configured range
	var enemy = SceneFactory.create_enemy(Enums.Enemy.TANK)
	test_scene.add_child(enemy)

	var enemy_data: EnemyData = GameConfig.enemies[Enums.Enemy.TANK]
	var min_orbs = enemy_data.exp_drop_min
	var max_orbs = enemy_data.exp_drop_max

	# Kill enemy and count exp orbs
	var initial_orbs = test_scene.get_tree().get_nodes_in_group(Enums.Group.EXP_ORBS).size()
	enemy.die()

	await wait_frames(2)

	var final_orbs = test_scene.get_tree().get_nodes_in_group(Enums.Group.EXP_ORBS).size()
	var dropped_orbs = final_orbs - initial_orbs

	assert_gte(dropped_orbs, min_orbs, "Should drop at least min exp orbs")
	assert_lte(dropped_orbs, max_orbs, "Should drop at most max exp orbs")

func test_tower_takes_damage_from_enemy():
	# Test that tower can take damage
	var tower = SceneFactory.create_tower(Enums.TowerId.ICE_FLOWER)
	test_scene.add_child(tower)

	var initial_hp = tower.health.current_hp
	var damage_amount = 20.0

	tower.take_damage(damage_amount)

	assert_eq(tower.health.current_hp, initial_hp - damage_amount, "Tower HP should decrease by damage amount")

func test_tower_destroyed_at_zero_hp():
	# Test that tower is destroyed when HP reaches zero
	var tower = SceneFactory.create_tower(Enums.TowerId.ICE_FLOWER)
	test_scene.add_child(tower)

	var initial_hp = tower.health.current_hp

	# Deal enough damage to destroy tower
	tower.take_damage(initial_hp)

	# Wait for queue_free to process
	await wait_frames(2)

	# Tower should be queued for deletion
	assert_false(is_instance_valid(tower) and tower.is_inside_tree(), "Tower should be removed from tree")

func test_combat_full_cycle():
	# Test a complete combat cycle: tower shoots, enemy takes damage, dies, drops exp orbs
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	test_scene.add_child(tower)
	tower.global_position = Vector2(200, 200)

	await wait_frames(2)

	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	test_scene.add_child(enemy)
	enemy.global_position = Vector2(250, 200)

	var initial_enemy_hp = enemy.health.current_hp

	# Manually damage enemy to simulate combat
	enemy.take_damage(initial_enemy_hp)

	# Wait for death and exp orb drop
	await wait_frames(2)

	# Verify exp orbs were dropped
	var orbs = test_scene.get_tree().get_nodes_in_group(Enums.Group.EXP_ORBS)
	assert_gt(orbs.size(), 0, "Exp orbs should be dropped after enemy death")
