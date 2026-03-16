extends GutTest

func test_default_values():
	var config := MeleeConfig.new()
	assert_eq(config.thrust_distance, 15.0)
	assert_eq(config.hit_radius, 20.0)
	assert_eq(config.knockback_force, 50.0)
