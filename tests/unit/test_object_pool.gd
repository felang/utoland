extends GutTest

func test_register_pool():
	var scene: PackedScene = preload("res://scenes/entities/coin.tscn")
	SceneFactory._register_pool("test_coin", scene)
	assert_true(SceneFactory._pools.has("test_coin"), "注册后应有 test_coin 池")
	SceneFactory._pools.erase("test_coin")

func test_pool_warmup():
	var scene: PackedScene = preload("res://scenes/entities/coin.tscn")
	SceneFactory._register_pool("test_coin_w", scene)
	SceneFactory._pool_warmup("test_coin_w", 5)
	assert_eq(SceneFactory._pools["test_coin_w"].idle_queue.size(), 5, "预热后应有 5 个空闲对象")
	for obj in SceneFactory._pools["test_coin_w"].idle_queue:
		obj.queue_free()
	SceneFactory._pools.erase("test_coin_w")

func test_clear_all_pools():
	var scene: PackedScene = preload("res://scenes/entities/coin.tscn")
	SceneFactory._register_pool("test_coin_c", scene)
	SceneFactory._pool_warmup("test_coin_c", 3)
	SceneFactory.clear_all_pools()
	assert_true(SceneFactory._pools.is_empty(), "clear_all_pools 后池应为空")

func test_coin_reset_for_pool():
	var coin: Area2D = SceneFactory.create_coin()
	add_child(coin)
	coin.value = 5
	coin.is_attracted = true
	coin.attract_speed = 999.0
	coin.modulate.a = 0.0
	coin.scale = Vector2(0.1, 0.1)
	coin.reset_for_pool()
	assert_eq(coin.value, 1, "reset 后 value 应为 1")
	assert_false(coin.is_attracted, "reset 后 is_attracted 应为 false")
	assert_eq(coin.attract_speed, 250.0, "reset 后 attract_speed 应为默认值")
	assert_eq(coin.attract_range, 75.0, "reset 后 attract_range 应为默认值")
	assert_null(coin.player, "reset 后 player 应为 null")
	assert_eq(coin.modulate.a, 1.0, "reset 后 modulate.a 应为 1.0")
	assert_eq(coin.scale, Vector2.ONE, "reset 后 scale 应为 ONE")
	coin.queue_free()

func test_coin_pool_acquire_and_release():
	var coin: Area2D = SceneFactory.create_coin()
	add_child(coin)
	coin.value = 10
	SceneFactory.release_coin(coin)
	assert_null(coin.get_parent(), "回收后不应有 parent")
	var coin2: Area2D = SceneFactory.create_coin()
	assert_eq(coin, coin2, "应复用同一 coin 对象")
	assert_eq(coin2.value, 1, "复用后 value 应已重置")
	add_child(coin2)
	SceneFactory.release_coin(coin2)

func test_coin_double_release_ignored():
	var coin: Area2D = SceneFactory.create_coin()
	add_child(coin)
	SceneFactory.release_coin(coin)
	var idle_count: int = SceneFactory._pools["coin"].idle_queue.size()
	SceneFactory.release_coin(coin)
	assert_eq(SceneFactory._pools["coin"].idle_queue.size(), idle_count, "双重回收不应增加队列")
	# 从池中取出再释放，避免 queue_free 池内节点污染后续测试
	var acquired: Area2D = SceneFactory.create_coin()
	SceneFactory.release_coin(acquired)

func test_exp_orb_reset_for_pool():
	var orb: Area2D = SceneFactory.create_exp_orb()
	add_child(orb)
	orb.value = 10
	orb.is_attracted = true
	orb.attract_speed = 500.0
	orb.modulate.a = 0.0
	orb.reset_for_pool()
	assert_eq(orb.value, 1, "reset 后 value 应为 1")
	assert_false(orb.is_attracted, "reset 后 is_attracted 应为 false")
	assert_eq(orb.attract_speed, 200.0, "reset 后 attract_speed 应为默认值")
	assert_eq(orb.attract_range, 30.0, "reset 后 attract_range 应为默认值")
	assert_null(orb.player, "reset 后 player 应为 null")
	orb.queue_free()

func test_exp_orb_pool_acquire_and_release():
	var orb: Area2D = SceneFactory.create_exp_orb()
	add_child(orb)
	orb.value = 10
	SceneFactory.release_exp_orb(orb)
	var orb2: Area2D = SceneFactory.create_exp_orb()
	assert_eq(orb, orb2, "应复用同一 exp_orb 对象")
	assert_eq(orb2.value, 1, "复用后 value 应已重置")
	add_child(orb2)
	SceneFactory.release_exp_orb(orb2)

func test_projectile_reset_for_pool():
	var pd := ProjectileData.new()
	pd.speed = 800.0
	pd.lifetime = 5.0
	pd.sprite_path = ""
	pd.projectile_scene = preload("res://scenes/entities/projectiles/arrow.tscn")
	var proj: Node2D = SceneFactory.create_projectile(pd, 10.0, Vector2(100, 100), Vector2.RIGHT)
	add_child(proj)
	# LinearMovementComponent 持有 _elapsed
	var lmc = proj.get_node_or_null("LinearMovementComponent")
	if lmc:
		lmc._elapsed = 3.0
	proj.reset_for_pool()
	if lmc:
		assert_eq(lmc._elapsed, 0.0, "reset 后 LinearMovementComponent._elapsed 应为 0")
	assert_true(proj.visible, "reset 后应可见")
	proj.queue_free()

func test_projectile_pool_reuse():
	var pd := ProjectileData.new()
	pd.speed = 800.0
	pd.lifetime = 5.0
	pd.sprite_path = ""
	pd.projectile_scene = preload("res://scenes/entities/projectiles/arrow.tscn")
	var proj1: Node2D = SceneFactory.create_projectile(pd, 10.0, Vector2.ZERO, Vector2.RIGHT)
	add_child(proj1)
	SceneFactory.release_projectile(proj1)
	# 投射物回收是异步延迟的（call_deferred），等待一帧让回收完成
	await get_tree().process_frame
	var proj2: Node2D = SceneFactory.create_projectile(pd, 20.0, Vector2(50, 50), Vector2.LEFT)
	assert_eq(proj1, proj2, "应复用同一投射物对象")
	# LinearMovementComponent 持有 speed
	var lmc = proj2.get_node_or_null("LinearMovementComponent")
	assert_not_null(lmc, "复用后应有 LinearMovementComponent")
	assert_eq(lmc.speed, 800.0, "复用后 speed 应来自 setup")
	proj2.queue_free()

func test_enemy_reset_for_pool():
	var enemy: CharacterBody2D = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	add_child(enemy)
	enemy.is_elite = true
	enemy._elite_coin_mult = 2.0
	enemy._elite_exp_mult = 2.0
	enemy.scale = Vector2(1.5, 1.5)
	enemy.current_state = enemy.State.ATTACK_TOWER
	enemy.velocity = Vector2(100, 0)
	enemy.attack_timer = 0.5
	enemy.visible = false
	enemy.reset_for_pool()
	assert_false(enemy.is_elite, "reset 后 is_elite 应为 false")
	assert_eq(enemy._elite_coin_mult, 1.0, "reset 后 coin mult 应为 1.0")
	assert_eq(enemy._elite_exp_mult, 1.0, "reset 后 exp mult 应为 1.0")
	assert_eq(enemy.scale, Vector2.ONE, "reset 后 scale 应为 ONE")
	assert_eq(enemy.current_state, enemy.State.CHASE_PLAYER, "reset 后应为 CHASE_PLAYER")
	assert_null(enemy.target_tower, "reset 后 target_tower 应为 null")
	assert_eq(enemy.velocity, Vector2.ZERO, "reset 后 velocity 应为 ZERO")
	assert_eq(enemy.attack_timer, 0.0, "reset 后 attack_timer 应为 0")
	assert_true(enemy.visible, "reset 后应可见")
	enemy.queue_free()

func test_enemy_pool_reuse_reinitializes():
	# 确保敌人池已注册（可能被 test_clear_all_pools 清空）
	if not SceneFactory._pools.has("enemy_normal"):
		SceneFactory._register_pool("enemy_normal", preload("res://scenes/entities/enemies/enemy_normal.tscn"))
	var enemy1: CharacterBody2D = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	add_child(enemy1)
	var original_speed: float = enemy1.speed
	enemy1.speed = 999.0
	enemy1.tower_attack_damage = 999.0
	SceneFactory.release_enemy(enemy1)
	await get_tree().process_frame
	var enemy2: CharacterBody2D = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	assert_eq(enemy1, enemy2, "应复用同一敌人对象")
	assert_eq(enemy2.speed, original_speed, "复用后 speed 应从 data 重新初始化")
	assert_false(enemy2.health.is_dead(), "复用后不应处于死亡状态")
	enemy2.queue_free()

func test_enemy_double_release_ignored():
	# 确保敌人池已注册（可能被 test_clear_all_pools 清空）
	if not SceneFactory._pools.has("enemy_normal"):
		SceneFactory._register_pool("enemy_normal", preload("res://scenes/entities/enemies/enemy_normal.tscn"))
	var enemy: CharacterBody2D = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	add_child(enemy)
	SceneFactory.release_enemy(enemy)
	await get_tree().process_frame
	var idle_count: int = SceneFactory._pools["enemy_normal"].idle_queue.size()
	SceneFactory.release_enemy(enemy)
	await get_tree().process_frame
	assert_eq(SceneFactory._pools["enemy_normal"].idle_queue.size(), idle_count, "双重回收不应增加队列")
	# 从池中取出再释放，保持池状态干净（不直接 queue_free 池内节点）
	var acquired: CharacterBody2D = SceneFactory.create_enemy(Enums.Enemy.NORMAL)
	SceneFactory.release_enemy(acquired)
	await get_tree().process_frame

func test_warmup_initial():
	SceneFactory.clear_all_pools()
	SceneFactory._ready()
	SceneFactory.warmup_initial()
	assert_true(SceneFactory._pools.has("coin"), "应有 coin 池")
	assert_true(SceneFactory._pools["coin"].idle_queue.size() >= 15, "coin 池应有 >= 15 个预热对象")
	assert_true(SceneFactory._pools["exp_orb"].idle_queue.size() >= 15, "exp_orb 池应有 >= 15 个预热对象")
	assert_true(SceneFactory._pools["enemy_normal"].idle_queue.size() >= 10, "enemy_normal 池应有 >= 10 个预热对象")
	SceneFactory.clear_all_pools()
	SceneFactory._ready()

func test_warmup_for_wave_fills_gap():
	SceneFactory.clear_all_pools()
	SceneFactory._ready()
	var wd := WaveData.new()
	wd.max_alive_enemies = 20
	wd.enemy_weights = {Enums.Enemy.NORMAL: 1.0}
	SceneFactory.warmup_for_wave(wd)
	assert_true(SceneFactory._pools["enemy_normal"].idle_queue.size() >= 20, "应按 max_alive_enemies 补充")
	SceneFactory.clear_all_pools()
	SceneFactory._ready()
