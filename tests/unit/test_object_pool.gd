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
