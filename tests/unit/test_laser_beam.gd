extends GutTest

# LaserProjectile 单元测试

func test_laser_projectile_default_duration():
	var beam: LaserProjectile = SceneFactory.create_laser_projectile()
	assert_eq(beam.beam_duration, 0.08, "默认持续时间应为 0.08 秒")
	beam.queue_free()
