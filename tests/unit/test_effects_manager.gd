extends GutTest

# EffectsManager 单元测试

func test_hitstop_changes_time_scale():
	EffectsManager.hitstop(0.05, 0.01)
	assert_lt(Engine.time_scale, 1.0, "time_scale 应小于 1")
	await get_tree().create_timer(0.05, true, false, true).timeout
	assert_eq(Engine.time_scale, 1.0, "time_scale 应恢复为 1.0")

