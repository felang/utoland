extends GutTest

# EffectsManager 单元测试

func test_hitstop_changes_time_scale():
	EffectsManager.hitstop(0.05, 0.01)
	assert_lt(Engine.time_scale, 1.0, "time_scale 应小于 1")
	await get_tree().create_timer(0.05, true, false, true).timeout
	assert_eq(Engine.time_scale, 1.0, "time_scale 应恢复为 1.0")

func test_flash_hit_changes_modulate():
	var sprite := Sprite2D.new()
	add_child(sprite)
	var original_mod: Color = sprite.modulate
	EffectsManager.flash_hit(sprite)
	assert_ne(sprite.modulate, original_mod, "modulate 应被改为红色")
	await get_tree().create_timer(0.1).timeout
	assert_eq(sprite.modulate, original_mod, "modulate 应恢复原色")
	sprite.queue_free()

