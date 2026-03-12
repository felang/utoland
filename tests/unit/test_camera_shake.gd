extends GutTest

# 摄像机系统单元测试

var shake_script = preload("res://scripts/systems/camera_shake.gd")

func test_shake_sets_trauma():
	var camera = Camera2D.new()
	camera.set_script(shake_script)
	add_child_autoqfree(camera)
	camera.shake(3.0, 0.1)
	assert_gt(camera._trauma, 0.0, "调用 shake 后 trauma 应大于 0")

func test_shake_takes_max_trauma():
	var camera = Camera2D.new()
	camera.set_script(shake_script)
	add_child_autoqfree(camera)
	camera.shake(2.0, 0.1)
	var first_trauma = camera._trauma
	camera.shake(5.0, 0.2)
	assert_gte(camera._trauma, first_trauma, "多次 shake 应取更大值")

func test_trauma_decays_over_time():
	var camera = Camera2D.new()
	camera.set_script(shake_script)
	add_child_autoqfree(camera)
	camera.shake(5.0, 0.5)
	var initial = camera._trauma
	camera._process(0.1)
	assert_lt(camera._trauma, initial, "trauma 应随时间衰减")

func test_camera_zoom_from_config():
	var camera = Camera2D.new()
	camera.set_script(shake_script)
	add_child_autoqfree(camera)
	await get_tree().process_frame
	var expected_zoom: Vector2 = Vector2(GameConfig.effects.camera_zoom, GameConfig.effects.camera_zoom)
	assert_eq(camera.zoom, expected_zoom, "摄像机缩放应从 float 配置转为 Vector2")

func test_camera_has_map_limits():
	var camera = Camera2D.new()
	camera.set_script(shake_script)
	add_child_autoqfree(camera)
	await get_tree().process_frame
	assert_eq(camera.limit_left, -int(GameConfig.MAP_HALF_WIDTH), "左边界应为地图左端")
	assert_eq(camera.limit_right, int(GameConfig.MAP_HALF_WIDTH), "右边界应为地图右端")

func test_camera_drag_margins_from_config():
	var camera = Camera2D.new()
	camera.set_script(shake_script)
	add_child_autoqfree(camera)
	await get_tree().process_frame
	assert_true(camera.drag_horizontal_enabled, "水平拖拽应启用")
	assert_true(camera.drag_vertical_enabled, "垂直拖拽应启用")
	var fx: EffectConfigData = GameConfig.effects
	assert_almost_eq(camera.drag_left_margin, fx.camera_dead_zone_width, 0.001, "左拖拽边距应匹配配置")
	assert_almost_eq(camera.drag_right_margin, fx.camera_dead_zone_width, 0.001, "右拖拽边距应匹配配置")

func test_camera_smoothing_enabled():
	var camera = Camera2D.new()
	camera.set_script(shake_script)
	add_child_autoqfree(camera)
	await get_tree().process_frame
	assert_true(camera.position_smoothing_enabled, "平滑跟随应开启")

func test_look_ahead_updates():
	var camera = Camera2D.new()
	camera.set_script(shake_script)
	add_child_autoqfree(camera)
	await get_tree().process_frame
	camera.update_look_ahead(Vector2(200, 0))
	assert_ne(camera._look_ahead_offset, Vector2.ZERO, "有速度时前瞻偏移应非零")
