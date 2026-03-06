extends GutTest

# 屏幕震动系统单元测试

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
