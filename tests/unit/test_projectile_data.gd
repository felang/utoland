extends GutTest

func test_default_values():
	var data := ProjectileData.new()
	assert_eq(data.speed, 300.0)
	assert_eq(data.lifetime, 5.0)
	assert_eq(data.base_pierce_count, 0)
	assert_eq(data.slow_ratio, 0.0)
	assert_eq(data.knockback_force, 0.0)

func test_slow_configuration():
	var data := ProjectileData.new()
	data.slow_ratio = 0.3
	data.slow_duration = 2.0
	assert_gt(data.slow_ratio, 0.0, "减速比例应大于 0")
	assert_gt(data.slow_duration, 0.0, "减速持续应大于 0")
