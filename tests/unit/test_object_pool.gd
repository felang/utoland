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
