extends GutTest

var test_scene: Node2D

# 信号回调辅助变量（避免 lambda 在 headless 测试中不可靠的问题）
var _destroyed_signal_received := false
var _destroyed_deploy_id: int = -1

func _on_test_tower_destroyed(_type: String, _pos: Vector2, did: int) -> void:
	_destroyed_signal_received = true
	_destroyed_deploy_id = did

func before_each() -> void:
	test_scene = Node2D.new()
	add_child_autofree(test_scene)
	PlayerState.reset()
	InventoryManager.reset()
	_destroyed_signal_received = false
	_destroyed_deploy_id = -1

func after_each() -> void:
	if EventBus.tower_destroyed.is_connected(_on_test_tower_destroyed):
		EventBus.tower_destroyed.disconnect(_on_test_tower_destroyed)

func test_tower_breaker_damages_and_destroys_tower():
	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	test_scene.add_child(tower)
	tower.global_position = Vector2(200, 200)
	tower.deploy_id = 1
	InventoryManager.deployed_towers.append({
		id = "pea_shooter", level = 1, grid_pos = Vector2i(5, 5), deploy_id = 1
	})

	await wait_frames(2)

	var initial_hp: float = tower.health.current_hp
	assert_gt(initial_hp, 0.0, "塔应有初始血量")

	tower.take_damage(20.0)
	assert_lt(tower.health.current_hp, initial_hp, "塔应受伤")

	EventBus.tower_destroyed.connect(_on_test_tower_destroyed)
	tower.take_damage(tower.health.current_hp + 10.0)
	await wait_frames(2)

	assert_true(_destroyed_signal_received, "应触发 tower_destroyed 信号")
	assert_eq(_destroyed_deploy_id, 1, "tower_destroyed 应携带正确 deploy_id")
	assert_false(is_instance_valid(tower) and tower.is_inside_tree(), "塔应被移除")

func test_tower_breaker_full_targeting_flow():
	var enemy = SceneFactory.create_enemy(Enums.Enemy.TOWER_BREAKER)
	test_scene.add_child(enemy)
	enemy.global_position = Vector2(100, 100)

	var tower = SceneFactory.create_tower(Enums.TowerId.PEA_SHOOTER)
	test_scene.add_child(tower)
	tower.global_position = Vector2(300, 100)

	await wait_frames(2)

	assert_eq(enemy.data.targets_towers, true, "拆塔者应有 targets_towers=true")

	# 强制刷新目标（绕过计时器冷却）
	enemy._target_refresh_timer = 0.0
	enemy._update_tower_target(0.1)
	assert_eq(enemy._tower_target, tower, "应锁定塔")

	tower.queue_free()
	await wait_frames(2)

	enemy._target_refresh_timer = 0.0
	enemy._update_tower_target(0.1)
	assert_null(enemy._tower_target, "塔被毁后应退化追玩家")

func test_wave_heal_restores_tower_hp():
	var tower = SceneFactory.create_tower(Enums.TowerId.ICE_FLOWER)
	test_scene.add_child(tower)

	await wait_frames(2)

	var max_hp: float = tower.health.max_hp
	tower.take_damage(max_hp * 0.5)
	var hp_before_heal: float = tower.health.current_hp
	tower.heal(max_hp * 0.3)
	assert_almost_eq(tower.health.current_hp, hp_before_heal + max_hp * 0.3, 0.01,
		"波间应恢复 30% 最大血量")
