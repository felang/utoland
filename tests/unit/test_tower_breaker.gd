extends GutTest

func test_enemy_data_has_targets_towers_field():
	var data := EnemyData.new()
	assert_eq(data.targets_towers, false, "targets_towers 默认应为 false")

func test_enemy_data_targets_towers_settable():
	var data := EnemyData.new()
	data.targets_towers = true
	assert_eq(data.targets_towers, true, "targets_towers 应可设为 true")

func test_enums_has_tower_breaker():
	assert_eq(Enums.Enemy.TOWER_BREAKER, "tower_breaker")

var test_scene: Node2D

func before_each():
	test_scene = Node2D.new()
	add_child_autofree(test_scene)
	PlayerState.reset()

func _make_tower_breaker_data() -> EnemyData:
	var data := EnemyData.new()
	data.id = "tower_breaker"
	data.hp = 150.0
	data.speed = 100.0
	data.damage = 20.0
	data.exp_drop_min = 2
	data.exp_drop_max = 3
	data.targets_towers = true
	return data

func test_tower_breaker_targets_nearest_tower():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	test_scene.add_child(enemy)
	enemy.data = _make_tower_breaker_data()
	enemy.global_position = Vector2(100, 100)

	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	test_scene.add_child(tower)
	tower.global_position = Vector2(200, 100)

	enemy._target_refresh_timer = 0.0
	enemy._update_tower_target(0.1)

	assert_eq(enemy._tower_target, tower, "应锁定最近的塔")

func test_tower_breaker_fallback_to_player():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	test_scene.add_child(enemy)
	enemy.data = _make_tower_breaker_data()

	enemy._target_refresh_timer = 0.0
	enemy._update_tower_target(0.1)

	assert_null(enemy._tower_target, "没有塔时 _tower_target 应为 null（退化追玩家）")

func test_tower_breaker_retargets_after_tower_destroyed():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	test_scene.add_child(enemy)
	enemy.data = _make_tower_breaker_data()
	enemy.global_position = Vector2(100, 100)

	var tower1 = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	test_scene.add_child(tower1)
	tower1.global_position = Vector2(200, 100)

	var tower2 = SceneFactory.create_tower(Enums.TowerId.ICE_FLOWER)
	test_scene.add_child(tower2)
	tower2.global_position = Vector2(300, 100)

	enemy._target_refresh_timer = 0.0
	enemy._update_tower_target(0.1)
	assert_eq(enemy._tower_target, tower1)

	tower1.queue_free()
	await wait_frames(2)

	enemy._target_refresh_timer = 0.0
	enemy._update_tower_target(0.1)
	assert_eq(enemy._tower_target, tower2, "应切换到下一个塔")

func test_normal_enemy_ignores_towers():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	test_scene.add_child(enemy)
	assert_eq(enemy.data.targets_towers, false, "普通敌人不追塔")
	assert_null(enemy._tower_target, "_tower_target 应为 null")

func test_game_config_has_tower_breaker():
	assert_true(GameConfig.enemies.has("tower_breaker"), "GameConfig 应注册 tower_breaker")
	var data: EnemyData = GameConfig.enemies["tower_breaker"]
	assert_eq(data.targets_towers, true, "拆塔者 targets_towers 应为 true")
	assert_gt(data.hp, 100.0, "拆塔者 HP 应高于普通怪")

func test_scene_factory_creates_tower_breaker():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.TOWER_BREAKER)
	assert_not_null(enemy, "SceneFactory 应能创建 tower_breaker")
	test_scene.add_child(enemy)
	assert_eq(enemy.data.targets_towers, true, "创建的 tower_breaker 应有 targets_towers=true")
