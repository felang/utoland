extends GutTest

# 回旋镖实体单元测试

func test_boomerang_initial_state_is_outbound():
	var boomerang: Area2D = SceneFactory.create_boomerang()
	assert_eq(boomerang._state, "OUTBOUND", "初始状态应为 OUTBOUND")
	boomerang.queue_free()

func test_boomerang_has_damage():
	var boomerang: Area2D = SceneFactory.create_boomerang()
	assert_eq(boomerang.damage, 0.0, "默认伤害应为 0")
	boomerang.queue_free()

func test_boomerang_has_speed():
	var boomerang: Area2D = SceneFactory.create_boomerang()
	assert_gt(boomerang.speed, 0.0, "速度应大于 0")
	boomerang.queue_free()

func test_boomerang_has_outbound_distance():
	var boomerang: Area2D = SceneFactory.create_boomerang()
	assert_gt(boomerang.outbound_distance, 0.0, "去程距离应大于 0")
	boomerang.queue_free()

func test_boomerang_tracks_hit_enemies():
	var boomerang: Area2D = SceneFactory.create_boomerang()
	assert_eq(boomerang._hit_outbound.size(), 0, "去程命中列表应为空")
	assert_eq(boomerang._hit_returning.size(), 0, "回程命中列表应为空")
	boomerang.queue_free()

func test_boomerang_max_lifetime():
	var boomerang: Area2D = SceneFactory.create_boomerang()
	assert_eq(boomerang.max_lifetime, 5.0, "最大存活时间应为 5 秒")
	boomerang.queue_free()
