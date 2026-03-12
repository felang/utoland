extends GutTest

func test_camera_zoom_is_float():
	var fx: EffectConfigData = GameConfig.effects
	assert_typeof(fx.camera_zoom, TYPE_FLOAT, "camera_zoom 应为 float 类型")

func test_camera_dead_zone_fields_exist():
	var fx: EffectConfigData = GameConfig.effects
	assert_gt(fx.camera_dead_zone_width, 0.0, "dead_zone_width 应大于 0")
	assert_gt(fx.camera_dead_zone_height, 0.0, "dead_zone_height 应大于 0")

func test_map_size_ratio_exists():
	var fx: EffectConfigData = GameConfig.effects
	assert_gt(fx.map_size_ratio, 0.0, "map_size_ratio 应大于 0")
